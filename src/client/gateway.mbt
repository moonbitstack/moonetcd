// The HTTP/JSON gateway transport: etcd's second address for the same services, on
// the same port. A call is a `POST` of one JSON message and a JSON reply; a stream is
// a `POST` whose reply keeps coming. The messages themselves — keys in base64, 64-bit
// integers as strings — are framed by the root package, so this file is HTTP and
// nothing else.

///|
/// etcd over its HTTP/JSON gateway. Built by `Client::connect_gateway`.
///
/// A unary call keeps its connection for the next one; the pool is what makes a
/// client shared by many tasks cheap. A stream owns its connection until it ends,
/// because the gateway streams one call per request — there is no duplex to multiplex
/// on.
pub struct GatewayTransport {
  targets : Array[(String, Int32)]
  idle : Array[HttpConn]
  mut next_endpoint : Int32
  mutex : @async.Mutex
  // What every connection dials with; `None` unless the configuration enables TLS.
  tls : @tls.Client?
}

///|
/// Note the endpoints. Nothing is dialled until the first call, so a member that is
/// down costs a retry rather than a failed `connect`.
fn GatewayTransport::connect(
  targets : Array[(String, Int32)],
  tls? : @tls.Client,
) -> GatewayTransport {
  { targets, idle: [], next_endpoint: 0, mutex: @async.Mutex::Mutex(), tls, }
}

///|
/// The `i`-th endpoint, wrapping around.
fn GatewayTransport::endpoint_at(
  self : GatewayTransport,
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
/// A connection to use, and whether it came from the pool — a pooled connection may
/// have been closed by the server while it sat idle, and a call that fails on one of
/// those has not reached etcd at all.
async fn GatewayTransport::checkout(
  self : GatewayTransport,
) -> (HttpConn, Bool) raise EtcdError {
  self.mutex.acquire()
  let idle = self.idle.pop()
  self.mutex.release()
  match idle {
    Some(conn) => (conn, true)
    None => {
      let endpoint = self.dial_target()
      (self.open(endpoint.0, endpoint.1), false)
    }
  }
}

///|
/// A fresh connection to one endpoint, with this transport's TLS settings.
async fn GatewayTransport::open(
  self : GatewayTransport,
  host : String,
  port : Int32,
) -> HttpConn raise EtcdError {
  HttpConn::open(host, port, tls?=self.tls)
}

///|
/// The endpoint its turn has come to, for a connection that is not pooled.
fn GatewayTransport::dial_target(self : GatewayTransport) -> (String, Int32) {
  let endpoint = self.endpoint_at(self.next_endpoint)
  self.next_endpoint = self.next_endpoint + 1
  endpoint
}

///|
/// Give a working connection back, or drop a broken one.
async fn GatewayTransport::checkin(
  self : GatewayTransport,
  conn : HttpConn,
) -> Unit noraise {
  let room = if self.targets.length() > 0 { self.targets.length() } else { 1 }
  if conn.is_reusable() && self.idle.length() < room {
    self.mutex.acquire()
    self.idle.push(conn)
    self.mutex.release()
  } else {
    conn.close()
  }
}

///|
/// One request and one reply over a pooled connection: the JSON text of the reply, or
/// the error the gateway reported.
async fn GatewayTransport::exchange(
  self : GatewayTransport,
  call : @moonetcd.GatewayCall,
  body : Bytes,
  metadata : Array[@header.Header],
) -> String raise EtcdError {
  let (conn, reused) = self.checkout()
  let outcome : Result[String, EtcdError] = Ok(
    round_trip(conn, call, body, metadata),
  ) catch {
    error => Err(error)
  }
  match outcome {
    Ok(text) => {
      self.checkin(conn)
      text
    }
    Err(error) => {
      conn.close()
      // A pooled connection the server had already closed fails before the request
      // is read, so one retry on a fresh connection is safe and is the difference
      // between a client that idles and one that does not.
      guard reused else { raise error }
      let (fresh, _) = self.checkout()
      errdefer fresh.close()
      let retried = round_trip(fresh, call, body, metadata)
      self.checkin(fresh)
      retried
    }
  }
}

///|
/// Post one request and read its whole reply.
async fn round_trip(
  conn : HttpConn,
  call : @moonetcd.GatewayCall,
  body : Bytes,
  metadata : Array[@header.Header],
) -> String raise EtcdError {
  conn.post(call.path, @utf8.encode(call.encode_request(body)), metadata)
  let head = conn.response_head()
  let reply = conn.body()
  let text = @utf8.decode_lossy(reply[:])
  if head.status >= 200 && head.status < 300 {
    text
  } else {
    raise @moonetcd.gateway_failure(text[:])
  }
}

///|
fn call_of(grpc_method : String) -> @moonetcd.GatewayCall raise EtcdError {
  match @moonetcd.gateway_call(grpc_method) {
    Some(call) => call
    None => raise refused(12, "the gateway has no such method: " + grpc_method)
  }
}

///|
impl Transport for GatewayTransport with fn unary(
  self : GatewayTransport,
  grpc_method : String,
  body : Bytes,
  metadata~ : Array[@header.Header],
  timeout? : Int32,
) -> Bytes raise EtcdError {
  let _ = timeout
  let call = call_of(grpc_method)
  let text = self.exchange(call, body, metadata)
  call.decode_reply(text[:])
}

///|
impl Transport for GatewayTransport with fn collect(
  self : GatewayTransport,
  grpc_method : String,
  body : Bytes,
  metadata~ : Array[@header.Header],
) -> Array[Bytes] raise EtcdError {
  let call = call_of(grpc_method)
  let text = self.exchange(call, body, metadata)
  let frames : Array[Bytes] = []
  for line in lines(text) {
    frames.push(call.decode_reply(line[:]))
  }
  frames
}

///|
impl Transport for GatewayTransport with fn watch(
  self : GatewayTransport,
  create : WatchCreateRequest,
  metadata~ : Array[@header.Header],
  group~ : @async.TaskGroup[Unit],
) -> &WatchStream raise EtcdError {
  let _ = group
  let call = call_of("/etcdserverpb.Watch/Watch")
  let stream : &WatchStream = GatewayWatchStream::open(
    self, call, create, metadata,
  )
  stream
}

///|
impl Transport for GatewayTransport with fn keep_alive(
  self : GatewayTransport,
  metadata~ : Array[@header.Header],
  group~ : @async.TaskGroup[Unit],
) -> &KeepAliveStream raise EtcdError {
  let _ = group
  let stream : &KeepAliveStream = GatewayKeepAliveStream::{
    transport: self,
    metadata,
    pending: [],
  }
  stream
}

///|
impl Transport for GatewayTransport with fn close(self : GatewayTransport) -> Unit {
  for conn in self.idle {
    conn.close()
  }
  self.idle.clear()
}

///|
/// The lines of a JSON body: the gateway separates the messages of a streamed reply
/// with a newline, and an unary reply is one line.
fn lines(text : String) -> Array[String] {
  let out : Array[String] = []
  let bytes = @utf8.encode(text)
  let mut start = 0
  for i = 0; i <= bytes.length(); i = i + 1 {
    if i == bytes.length() || bytes[i].to_int() == 10 {
      if i > start {
        out.push(@utf8.decode_lossy(bytes[start:i]))
      }
      start = i + 1
    }
  }
  out
}

///|
/// One watch over the gateway. Each event arrives as a line of a streamed reply; a
/// stream the server ends is re-opened from just past the last revision seen, so a
/// watched key is not missed because a connection went away.
pub struct GatewayWatchStream {
  transport : GatewayTransport
  call : @moonetcd.GatewayCall
  metadata : Array[@header.Header]
  mut conn : HttpConn
  mut create : WatchCreateRequest
  mut last_revision : Int64
  mut pending : Bytes
  mut reconnects : Int32
  mut closed : Bool
}

///|
async fn GatewayWatchStream::open(
  transport : GatewayTransport,
  call : @moonetcd.GatewayCall,
  create : WatchCreateRequest,
  metadata : Array[@header.Header],
) -> GatewayWatchStream raise EtcdError {
  let endpoint = transport.dial_target()
  let conn = transport.open(endpoint.0, endpoint.1)
  let stream = {
    transport,
    call,
    metadata,
    conn,
    create,
    last_revision: create.start_revision,
    pending: b"",
    reconnects: 0,
    closed: false,
  }
  stream.start()
  stream
}

///|
/// Send the create request and read the reply head, so a refused watch fails at the
/// call rather than at the first event.
async fn GatewayWatchStream::start(
  self : GatewayWatchStream,
) -> Unit raise EtcdError {
  let request = @moonetcd.WatchRequest::CreateRequest(self.create)
  self.conn.post(
    self.call.path,
    @utf8.encode(self.call.encode_request(request.encode())),
    self.metadata,
  )
  let head = self.conn.response_head()
  if head.status < 200 || head.status >= 300 {
    let body = self.conn.body()
    raise @moonetcd.gateway_failure(@utf8.decode_lossy(body[:])[:])
  }
}

///|
/// Take one whole line out of what has arrived, if there is one.
fn GatewayWatchStream::take_line(self : GatewayWatchStream) -> String? {
  let bytes = self.pending
  for i = 0; i < bytes.length(); i = i + 1 {
    if bytes[i].to_int() == 10 {
      let line = @utf8.decode_lossy(bytes[:i])
      self.pending = bytes[i + 1:].to_owned()
      if line != "" {
        return Some(line)
      }
      return self.take_line()
    }
  }
  None
}

///|
impl WatchStream for GatewayWatchStream with fn next(self : GatewayWatchStream) -> WatchResponse? raise EtcdError {
  for ;; {
    if self.closed {
      return None
    }
    match self.take_line() {
      Some(line) => {
        let response = WatchResponse::decode(self.call.decode_reply(line[:])) catch {
          _ => raise refused(13, "decode WatchResponse failed")
        }
        if response.header.revision > self.last_revision {
          self.last_revision = response.header.revision
        }
        return Some(response)
      }
      None =>
        match self.conn.next_event() {
          Data(data) => self.pending = append(self.pending, data)
          End(_) | Closed =>
            if !self.reconnect() {
              self.closed = true
              return None
            }
          _ => ()
        }
    }
  }
}

///|
/// Re-open the stream from just past the last revision seen, bounded so a cluster
/// that is down for good does not spin here.
async fn GatewayWatchStream::reconnect(
  self : GatewayWatchStream,
) -> Bool raise EtcdError {
  if self.reconnects >= 3 {
    return false
  }
  self.reconnects = self.reconnects + 1
  self.conn.close()
  let endpoint = self.transport.dial_target()
  self.conn = self.transport.open(endpoint.0, endpoint.1)
  self.pending = b""
  let from = if self.last_revision > 0 { self.last_revision + 1 } else { 0 }
  self.create = { ..self.create, start_revision: from, }
  self.start()
  true
}

///|
impl WatchStream for GatewayWatchStream with fn close(self : GatewayWatchStream) -> Unit {
  self.closed = true
  // Ending the request is how the gateway cancels the watch: it owns the stream.
  self.conn.close()
}

///|
/// Two byte strings one after the other.
fn append(first : Bytes, second : Bytes) -> Bytes {
  let buffer = @buffer.Buffer()
  buffer.write_bytes(first)
  buffer.write_bytes(second)
  buffer.to_bytes()
}

///|
/// A keep-alive session over the gateway. The gateway answers one request with one
/// acknowledgement and ends the reply, so each tick is its own exchange; `next`
/// returns what the last tick was told. That is fewer round trips than a stream only
/// when a client holds one lease, and it is the only shape the gateway offers.
pub struct GatewayKeepAliveStream {
  transport : GatewayTransport
  metadata : Array[@header.Header]
  pending : Array[LeaseKeepAliveResponse]
}

///|
impl KeepAliveStream for GatewayKeepAliveStream with fn keep_alive(
  self : GatewayKeepAliveStream,
  id : Int64,
) -> Unit raise EtcdError {
  let call = call_of("/etcdserverpb.Lease/LeaseKeepAlive")
  let request = @moonetcd.LeaseKeepAliveRequest::{ id, }
  let text = self.transport.exchange(call, request.encode(), self.metadata)
  for line in lines(text) {
    self.pending.push(
      LeaseKeepAliveResponse::decode(call.decode_reply(line[:])) catch {
        _ => raise refused(13, "decode KeepAliveResponse failed")
      },
    )
  }
}

///|
impl KeepAliveStream for GatewayKeepAliveStream with fn next(
  self : GatewayKeepAliveStream,
) -> LeaseKeepAliveResponse? raise EtcdError {
  if self.pending.length() == 0 {
    return None
  }
  Some(self.pending.remove(0))
}

///|
impl KeepAliveStream for GatewayKeepAliveStream with fn close(
  self : GatewayKeepAliveStream,
) -> Unit {
  self.pending.clear()
}
