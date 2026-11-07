// The etcd client. A `Client` owns one transport — gRPC or the HTTP/JSON gateway —
// and hands out typed handles (`KV`, `Watch`, `Lease`, `Cluster`, `Auth`,
// `Maintenance`, `Lock`, `Election`) that all answer through it. The handles are the
// same code either way: only the transport below them changes.

///|
/// A live etcd client. Construct it with `Client::connect` for gRPC or
/// `Client::connect_gateway` for the HTTP/JSON gateway; the handles returned by `kv`,
/// `watch`, `lease`, … share its connection.
pub struct Client {
  transport : &Transport
  config : @moonetcd.ClientConfig
  targets : Array[(String, Int32)]
  mut token : String
}

///|
/// Accumulate the decimal digits in `s` into an `Int32` (ignoring non-digits).
fn digits_to_int32(s : String) -> Int32 {
  let chars = s.to_array()
  let mut acc : Int32 = 0
  for i = 0; i < chars.length(); i = i + 1 {
    let digit = chars[i].to_int()
    if digit >= 48 && digit <= 57 {
      acc = acc * 10 + (digit - 48)
    }
  }
  acc
}

///|
/// Split `"host:port"` into its parts; a missing port defaults to etcd's 2379.
fn parse_endpoint(endpoint : String) -> (String, Int32) {
  let chars = endpoint.to_array()
  let n = chars.length()
  let mut colon = -1
  let mut i = 0
  while i < n {
    if chars[i].to_int() == 58 {
      colon = i
    }
    i = i + 1
  }
  if colon < 0 {
    (endpoint, 2379)
  } else {
    let port = digits_to_int32(endpoint[colon + 1:].to_owned())
    (endpoint[:colon].to_owned(), if port == 0 { 2379 } else { port })
  }
}

///|
/// Dial the configured endpoints over gRPC and, if a username and password are set,
/// authenticate and cache the token. The token travels as the `token` metadata header
/// on every later call. TLS is dialled when the configuration enables it.
pub async fn Client::connect(
  config : @moonetcd.ClientConfig,
) -> Client raise EtcdError {
  let targets = config.endpoints.map(parse_endpoint)
  let tls = grpc_tls(config.tls)
  let transport : &Transport = GrpcTransport::connect(targets, tls?) catch {
    _ => raise transport_error("grpc connect")
  }
  // Building the client is the authentication handshake, which reports its own failure
  // through the token the calls carry; anything else here is a setup that did not hold.
  Client::of_transport(config, transport) catch {
    _ => raise transport_error("client setup")
  }
}

///|
/// Reach the same endpoints through etcd's HTTP/JSON gateway, which every etcd serves
/// on its client port. The handles are identical to the gRPC ones, down to the
/// messages they carry; only the wire changes, with keys and values in base64.
pub async fn Client::connect_gateway(
  config : @moonetcd.ClientConfig,
) -> Client raise EtcdError {
  let targets = config.endpoints.map(parse_endpoint)
  let transport : &Transport = GatewayTransport::connect(
    targets,
    tls?=gateway_tls(config.tls),
  )
  Client::of_transport(config, transport) catch {
    _ => raise transport_error("client setup")
  }
}

///|
/// A client over a transport of the caller's own, with the same authentication
/// handshake as the two that ship.
pub async fn Client::of_transport(
  config : @moonetcd.ClientConfig,
  transport : &Transport,
) -> Client {
  let targets = config.endpoints.map(parse_endpoint)
  let client = { transport, config, targets, token: config.token, }
  if config.username != "" && config.password != "" {
    let token = client.authenticate(config.username, config.password) catch {
      _ => ""
    }
    if token != "" {
      client.token = token
    }
  }
  client
}

///|
/// Authenticate with the given user and password and return the auth token. Call
/// `Client::connect` to have the token cached, or store the return value and set it on
/// the client when re-authenticating.
pub async fn Client::authenticate(
  self : Client,
  name : String,
  password : String,
) -> String raise EtcdError {
  let request = @moonetcd.AuthenticateRequest::{ name, password, }
  let response = self.rpc(
    "/etcdserverpb.Auth/Authenticate",
    request.encode(),
    @moonetcd.AuthenticateResponse::decode,
  )
  response.token
}

///|
/// The metadata for the next call: an empty list, or the cached auth token under the
/// `token` header that gRPC carries. The gateway transport moves it to the
/// `Authorization` header, which is where the gateway reads it.
fn Client::metadata(self : Client) -> Array[@header.Header] {
  if self.token == "" {
    []
  } else {
    [@header.Header::of("token", self.token)]
  }
}

///|
/// The number of configured endpoints.
pub fn Client::endpoint_count(self : Client) -> Int32 {
  self.targets.length()
}

///|
/// The i-th endpoint as `(host, port)`, wrapping around so the next endpoint after the
/// last is the first — the basis of stream failover.
pub fn Client::endpoint_at(self : Client, i : Int32) -> (String, Int32) {
  let n = self.targets.length()
  if n == 0 {
    ("127.0.0.1", 2379)
  } else {
    self.targets[i % n]
  }
}

///|
/// The calls that change nothing, which etcd's client calls repeatable: when the
/// connection dies under one, it can go again on the next member. A write cannot,
/// since it may have run.
let repeatable : Array[String] = [
  "/etcdserverpb.KV/Range", "/etcdserverpb.Lease/LeaseTimeToLive", "/etcdserverpb.Lease/LeaseLeases",
  "/etcdserverpb.Cluster/MemberList", "/etcdserverpb.Maintenance/Status", "/etcdserverpb.Maintenance/Alarm",
]

///|
/// One unary RPC: send `body` to `grpc_method`, decode the single reply with `decode`,
/// and let a dead connection retry a repeatable call on the next member.
async fn[R] Client::rpc(
  self : Client,
  grpc_method : String,
  body : Bytes,
  decode : (Bytes) -> R raise @proto.PbError,
  timeout? : Int32,
) -> R raise EtcdError {
  let metadata = self.metadata()
  let attempts = if repeatable.contains(grpc_method) {
    self.endpoint_count()
  } else {
    1
  }
  let mut last : EtcdError? = None
  for i = 0; i < attempts; i = i + 1 {
    let outcome : Result[Bytes, EtcdError] = Ok(
      self.transport.unary(grpc_method, body, metadata~, timeout?),
    ) catch {
      error => Err(error)
    }
    match outcome {
      Ok(reply) =>
        return decode(reply) catch {
          _ =>
            raise refused(13, "failed to decode response from " + grpc_method)
        }
      Err(@moonetcd.EtcdError::Refused(status)) =>
        if status.code == unavailable {
          last = Some(@moonetcd.EtcdError::Refused(status))
        } else {
          raise @moonetcd.EtcdError::Refused(status)
        }
      Err(error) => raise error
    }
  }
  raise last.unwrap()
}

///|
/// A server-streaming RPC: send `body` to `grpc_method` and collect every reply.
async fn Client::rpc_stream(
  self : Client,
  grpc_method : String,
  body : Bytes,
) -> Array[Bytes] raise EtcdError {
  self.transport.collect(grpc_method, body, metadata=self.metadata())
}

///|
/// Open a watch. `group` is the task group the stream's background work runs in, so
/// this must run inside `@async.with_task_group`.
async fn Client::watch_stream(
  self : Client,
  group : @async.TaskGroup[Unit],
  create : WatchCreateRequest,
) -> &WatchStream raise EtcdError {
  self.transport.watch(create, metadata=self.metadata(), group~)
}

///|
/// Open the lease keep-alive session, in the same task group.
async fn Client::keep_alive_stream(
  self : Client,
  group : @async.TaskGroup[Unit],
) -> &KeepAliveStream raise EtcdError {
  self.transport.keep_alive(metadata=self.metadata(), group~)
}

///|
/// Close every backend connection. Outstanding calls are abandoned.
pub fn Client::close(self : Client) -> Unit {
  self.transport.close()
}

///|
/// The KV handle: `Put`, `Range`, `DeleteRange`, `Txn`, `Compact`.
pub fn Client::kv(self : Client) -> KV {
  KV::{ client: self, }
}

///|
/// The Watch handle: a stream that resumes from the last revision.
pub fn Client::watch(self : Client) -> Watch {
  Watch::{ client: self, }
}

///|
/// The Lease handle: grant, revoke, TimeToLive, list, and KeepAlive.
pub fn Client::lease(self : Client) -> Lease {
  Lease::{ client: self, }
}

///|
/// The Cluster handle: member add/remove/update/list/promote.
pub fn Client::cluster(self : Client) -> Cluster {
  Cluster::{ client: self, }
}

///|
/// The Auth handle: enable/disable and user/role management.
pub fn Client::auth(self : Client) -> Auth {
  Auth::{ client: self, }
}

///|
/// The Maintenance handle: status, alarms, defragment, snapshot, leader moves.
pub fn Client::maintenance(self : Client) -> Maintenance {
  Maintenance::{ client: self, }
}

///|
/// The Lock handle: the v3lock service.
pub fn Client::lock(self : Client) -> Lock {
  Lock::{ client: self, }
}

///|
/// The Election handle: the v3election service.
pub fn Client::election(self : Client) -> Election {
  Election::{ client: self, }
}
