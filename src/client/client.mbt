// The etcd client. A `Client` owns one `@net.ManagedChannel` for unary and
// server/client streaming (multi-endpoint failover lives inside it) and hands out
// typed handles — `KV`, `Watch`, `Lease`, `Cluster`, `Auth`, `Maintenance`, `Lock`,
// `Election` — that all share that channel. The bidi sessions (Watch, Lease
// KeepAlive) open their own multiplexed channel so they can reconnect from the last
// revision without disturbing the unary path.

///|
/// A live etcd client. Construct it with `Client::connect`; the handles returned by
/// `kv`, `watch`, `lease`, … share its connection.
pub struct Client {
  channel : @net.ManagedChannel
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
    let d = chars[i].to_int()
    if d >= 48 && d <= 57 {
      acc = acc * 10 + (d - 48)
    }
  }
  acc
}

///|
/// Split `"host:port"` into its parts; a missing port defaults to etcd's 2379.
fn parse_endpoint(ep : String) -> (String, Int32) {
  let chars = ep.to_array()
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
    (ep, 2379)
  } else {
    let port = digits_to_int32(ep[colon + 1:].to_owned())
    (ep[:colon].to_owned(), if port == 0 { 2379 } else { port })
  }
}

///|
/// Dial the configured endpoints and, if a username and password are set, authenticate
/// and cache the token. The token is injected as the `token` metadata header on every
/// later call.
pub async fn Client::connect(config : @moonetcd.ClientConfig) -> Client {
  let targets = config.endpoints.map(parse_endpoint)
  let channel = @net.ManagedChannel::connect(targets)
  let c = { channel, config, targets, token: config.token, }
  if config.username != "" && config.password != "" {
    let token = c.authenticate(config.username, config.password) catch {
      _ => ""
    }
    if token != "" {
      c.token = token
    }
  }
  c
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
  let req = @moonetcd.AuthenticateRequest::{ name, password, }
  let resp = self.rpc(
    "/etcdserverpb.Auth/Authenticate",
    req.encode(),
    @moonetcd.AuthenticateResponse::decode,
  )
  resp.token
}

///|
/// The gRPC metadata for the next call: an empty list, or the cached auth token under
/// the `token` header that etcd expects.
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
/// last is the first — the basis of Watch/KeepAlive failover.
pub fn Client::endpoint_at(self : Client, i : Int32) -> (String, Int32) {
  let n = self.targets.length()
  if n == 0 {
    ("127.0.0.1", 2379)
  } else {
    self.targets[i % n]
  }
}

///|
/// Turn a non-OK gRPC status into an `EtcdError`. etcd reports a compacted or future
/// revision through a `FAILED_PRECONDITION` / `OUT_OF_RANGE` status whose message names
/// the revision, which we surface as `Compacted` / `FutureRev` exactly as clientv3 does.
fn map_error(status : @wire.Status, message : String) -> EtcdError {
  let code = status.code()
  let compacted = code == @wire.Status::FailedPrecondition.code() &&
    message.contains("required revision has been compacted")
  if compacted {
    return @moonetcd.EtcdError::Compacted(extract_rev(message))
  }
  let future = code == @wire.Status::OutOfRange.code() &&
    message.contains("required revision is a future revision")
  if future {
    return @moonetcd.EtcdError::FutureRev(extract_rev(message))
  }
  @moonetcd.EtcdError::Refused(@moonetcd.Status::{ code, message, })
}

///|
/// Pull the trailing decimal integer out of an etcd error message (e.g. the revision
/// in "etcdserver: mvcc: required revision has been compacted: 12345").
fn extract_rev(message : String) -> Int64 {
  let chars = message.to_array()
  let n = chars.length()
  let mut end = -1
  let mut i = n - 1
  while i >= 0 {
    let d = chars[i].to_int()
    if d >= 48 && d <= 57 {
      end = i + 1
      break
    }
    i = i - 1
  }
  if end < 0 {
    return 0L
  }
  let mut start = end - 1
  while start >= 0 && chars[start].to_int() >= 48 && chars[start].to_int() <= 57 {
    start = start - 1
  }
  let mut acc : Int64 = 0L
  let mut k = start + 1
  while k < end {
    acc = acc * 10L + Int64::from_int(chars[k].to_int() - 48)
    k = k + 1
  }
  acc
}

///|
/// The `EtcdError` a transport failure (a socket that dropped, a channel that never
/// dialled) turns into: `UNAVAILABLE`, as gRPC maps it.
fn transport_error(what : String) -> EtcdError {
  @moonetcd.EtcdError::Refused(@moonetcd.Status::{
    code: 14,
    message: "transport error: " + what,
  })
}

///|
/// One unary RPC: send `body` to `path` with the auth metadata, decode the single
/// reply with `decode`, and translate any transport or decode failure into `EtcdError`.
async fn[R] Client::rpc(
  self : Client,
  path : String,
  body : Bytes,
  decode : (Bytes) -> R raise @proto.PbError,
  timeout? : Int32,
) -> R raise EtcdError {
  let md = self.metadata()
  let reply = try {
    match timeout {
      Some(ms) => self.channel.unary(path, body, metadata=md, timeout_millis=ms)
      None => self.channel.unary(path, body, metadata=md)
    }
  } catch {
    _ => raise transport_error(path)
  }
  let msgs = reply.ok() catch {
    @wire.StatusError(s, m) => raise map_error(s, m)
  }
  match msgs {
    [one] => {
      let r = decode(one) catch {
        _ =>
          raise @moonetcd.EtcdError::Refused(@moonetcd.Status::{
            code: 13,
            message: "failed to decode response from " + path,
          })
      }
      r
    }
    _ =>
      raise @moonetcd.EtcdError::Refused(@moonetcd.Status::{
        code: 13,
        message: "unexpected response message count from " + path,
      })
  }
}

///|
/// A server-streaming RPC: send `body` to `path` and collect every reply message,
/// translated into `EtcdError` on any transport failure.
async fn Client::rpc_stream(
  self : Client,
  path : String,
  body : Bytes,
  timeout? : Int32,
) -> Array[Bytes] raise EtcdError {
  let md = self.metadata()
  let reply = try {
    match timeout {
      Some(ms) =>
        self.channel.server_streaming(
          path,
          body,
          metadata=md,
          timeout_millis=ms,
        )
      None => self.channel.server_streaming(path, body, metadata=md)
    }
  } catch {
    _ => raise transport_error(path)
  }
  reply.ok() catch {
    @wire.StatusError(s, m) => raise map_error(s, m)
  }
}

///|
/// Close every backend connection. Outstanding calls are abandoned.
pub fn Client::close(self : Client) -> Unit {
  self.channel.close()
}

///|
/// The KV handle: `Put`, `Range`, `DeleteRange`, `Txn`, `Compact`.
pub fn Client::kv(self : Client) -> KV {
  KV::{ client: self, }
}

///|
/// The Watch handle: a bidi stream that reconnects from the last revision.
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
