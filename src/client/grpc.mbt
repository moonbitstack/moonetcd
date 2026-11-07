// The gRPC transport: HTTP/2 with the etcd service definitions. Unary calls and the
// server-streaming snapshot go through a `ManagedChannel`, which balances across the
// configured endpoints; each watch and keep-alive session opens its own multiplexed
// channel, so a disconnect there cannot disturb anything else and the stream can
// resume from its last revision.

///|
/// etcd over gRPC. Built by `Client::connect`.
pub struct GrpcTransport {
  channel : @net.ManagedChannel
  targets : Array[(String, Int32)]
  // What every connection dials with; `None` unless the configuration enables TLS.
  tls : @tls.Client?
}

///|
/// Dial the endpoints. Nothing is sent until the first call.
pub async fn GrpcTransport::connect(
  targets : Array[(String, Int32)],
  tls? : @tls.Client,
) -> GrpcTransport {
  { channel: @net.ManagedChannel::connect(targets, tls?), targets, tls, }
}

///|
/// The `i`-th endpoint, wrapping around so a stream that has to move on reaches the
/// next member.
fn GrpcTransport::endpoint_at(
  self : GrpcTransport,
  i : Int32,
) -> (String, Int32) {
  let n = self.targets.length()
  if n == 0 {
    ("127.0.0.1", 2379)
  } else {
    self.targets[i % n]
  }
}

///|
impl Transport for GrpcTransport with fn unary(
  self : GrpcTransport,
  grpc_method : String,
  body : Bytes,
  metadata~ : Array[@header.Header],
  timeout? : Int32,
) -> Bytes raise EtcdError {
  let reply = try {
    match timeout {
      Some(millis) =>
        self.channel.unary(grpc_method, body, metadata~, timeout_millis=millis)
      None => self.channel.unary(grpc_method, body, metadata~)
    }
  } catch {
    _ => raise transport_error(grpc_method)
  }
  let messages = reply.ok() catch {
    @wire.StatusError(status, message) =>
      raise @moonetcd.EtcdError::of(status.code(), message)
  }
  match messages {
    [one] => one
    _ =>
      raise refused(13, "unexpected response message count from " + grpc_method)
  }
}

///|
impl Transport for GrpcTransport with fn collect(
  self : GrpcTransport,
  grpc_method : String,
  body : Bytes,
  metadata~ : Array[@header.Header],
) -> Array[Bytes] raise EtcdError {
  let reply = self.channel.server_streaming(grpc_method, body, metadata~) catch {
    _ => raise transport_error(grpc_method)
  }
  reply.ok() catch {
    @wire.StatusError(status, message) =>
      raise @moonetcd.EtcdError::of(status.code(), message)
  }
}

///|
impl Transport for GrpcTransport with fn watch(
  self : GrpcTransport,
  create : WatchCreateRequest,
  metadata~ : Array[@header.Header],
  group~ : @async.TaskGroup[Unit],
) -> &WatchStream raise EtcdError {
  let endpoint = self.endpoint_at(0)
  let mux = @net.MuxChannel::connect(endpoint.0, endpoint.1, tls?=self.tls) catch {
    _ => raise transport_error("watch dial")
  }
  group.spawn_bg(no_wait=true, () => mux.read_pump())
  let bidi = mux.open_bidi("/etcdserverpb.Watch/Watch", metadata~)
  let stream = GrpcWatchStream::{
    transport: self,
    group,
    metadata,
    mux,
    bidi,
    create,
    last_revision: create.start_revision,
    watch_id: 0,
    endpoint: 0,
    reconnects: 0,
    closed: false,
  }
  stream.send_create()
  stream
}

///|
impl Transport for GrpcTransport with fn keep_alive(
  self : GrpcTransport,
  metadata~ : Array[@header.Header],
  group~ : @async.TaskGroup[Unit],
) -> &KeepAliveStream raise EtcdError {
  let endpoint = self.endpoint_at(0)
  let mux = @net.MuxChannel::connect(endpoint.0, endpoint.1, tls?=self.tls) catch {
    _ => raise transport_error("keepalive dial")
  }
  group.spawn_bg(no_wait=true, () => mux.read_pump())
  @async.sleep(1)
  let bidi = mux.open_bidi("/etcdserverpb.Lease/LeaseKeepAlive", metadata~)
  let stream : &KeepAliveStream = GrpcKeepAliveStream::{ mux, bidi, }
  stream
}

///|
impl Transport for GrpcTransport with fn close(self : GrpcTransport) -> Unit {
  self.channel.close()
}

///|
/// One watch over gRPC. The stream carries the create request; on a dropped connection
/// it reconnects to the next endpoint and re-issues the create just past the last event
/// it saw — the resume etcd's own client does. Closing the channel is what cancels the
/// watch on the server.
pub struct GrpcWatchStream {
  transport : GrpcTransport
  group : @async.TaskGroup[Unit]
  metadata : Array[@header.Header]
  mut mux : @net.MuxChannel
  mut bidi : @net.BidiStream
  mut create : WatchCreateRequest
  mut last_revision : Int64
  mut watch_id : Int64
  mut endpoint : Int32
  mut reconnects : Int32
  mut closed : Bool
}

///|
/// (Re)send the current create request. The `Watch` method takes a `WatchRequest`
/// whose oneof tags the create as `create_request` (field 1), so the bare
/// `WatchCreateRequest` has to be wrapped, not sent on its own.
async fn GrpcWatchStream::send_create(
  self : GrpcWatchStream,
) -> Unit raise EtcdError {
  let request = @moonetcd.WatchRequest::CreateRequest(self.create)
  self.bidi.send(request.encode()) catch {
    _ => raise transport_error("watch send create")
  }
}

///|
impl WatchStream for GrpcWatchStream with fn next(self : GrpcWatchStream) -> WatchResponse? raise EtcdError {
  for ;; {
    if self.closed {
      return None
    }
    let raw = self.bidi.recv() catch {
      _ => raise transport_error("watch recv")
    }
    match raw {
      Some(bytes) => {
        let response = WatchResponse::decode(bytes) catch {
          _ => raise refused(13, "decode WatchResponse failed")
        }
        if response.watch_id != 0 {
          self.watch_id = response.watch_id
        }
        if response.header.revision > self.last_revision {
          self.last_revision = response.header.revision
        }
        return Some(response)
      }
      None => {
        if self.reconnects >= 3 {
          self.closed = true
          return None
        }
        self.reconnects = self.reconnects + 1
        self.reconnect()
      }
    }
  }
}

///|
/// Move to the next endpoint and resume from just after the last event seen.
async fn GrpcWatchStream::reconnect(
  self : GrpcWatchStream,
) -> Unit raise EtcdError {
  self.mux.close()
  self.endpoint = self.endpoint + 1
  let address = self.transport.endpoint_at(self.endpoint)
  let mux = @net.MuxChannel::connect(
    address.0,
    address.1,
    tls?=self.transport.tls,
  ) catch {
    _ => raise transport_error("watch reconnect dial")
  }
  self.group.spawn_bg(no_wait=true, () => mux.read_pump())
  let bidi = mux.open_bidi("/etcdserverpb.Watch/Watch", metadata=self.metadata)
  self.mux = mux
  self.bidi = bidi
  let from = if self.last_revision > 0 { self.last_revision + 1 } else { 0 }
  self.create = { ..self.create, start_revision: from, }
  self.send_create()
}

///|
impl WatchStream for GrpcWatchStream with fn close(self : GrpcWatchStream) -> Unit {
  self.closed = true
  // Closing the channel ends the bidi stream, which is what cancels the watch on
  // the server; a cancel message first would need an awaited send, and the server
  // treats the stream's end the same way.
  self.mux.close()
}

///|
/// One keep-alive session over gRPC: a bidi stream on its own connection, so it never
/// disturbs the unary path.
pub struct GrpcKeepAliveStream {
  mux : @net.MuxChannel
  bidi : @net.BidiStream
}

///|
impl KeepAliveStream for GrpcKeepAliveStream with fn keep_alive(
  self : GrpcKeepAliveStream,
  id : Int64,
) -> Unit raise EtcdError {
  let request = @moonetcd.LeaseKeepAliveRequest::{ id, }
  self.bidi.send(request.encode()) catch {
    _ => raise transport_error("keepalive send")
  }
}

///|
impl KeepAliveStream for GrpcKeepAliveStream with fn next(
  self : GrpcKeepAliveStream,
) -> LeaseKeepAliveResponse? raise EtcdError {
  let raw = self.bidi.recv() catch {
    _ => raise transport_error("keepalive recv")
  }
  match raw {
    Some(bytes) =>
      Some(
        LeaseKeepAliveResponse::decode(bytes) catch {
          _ => raise refused(13, "decode KeepAliveResponse failed")
        },
      )
    None => None
  }
}

///|
impl KeepAliveStream for GrpcKeepAliveStream with fn close(
  self : GrpcKeepAliveStream,
) -> Unit {
  self.mux.close()
}
