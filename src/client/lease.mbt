// Lease: grant, revoke, TimeToLive, list, and KeepAlive, over whichever transport the
// client uses.

///|
/// A typed handle for the Lease service. Obtain it with `client.lease()`.
pub struct Lease {
  client : Client
}

///|
/// Create a lease that lives for `ttl` seconds; an explicit `id` pins the lease id.
pub async fn Lease::grant(
  self : Lease,
  ttl : Int64,
  id? : Int64,
) -> LeaseGrantResponse raise EtcdError {
  let request = @moonetcd.LeaseGrantRequest::{ ttl, id: id.unwrap_or(0), }
  self.client.rpc(
    "/etcdserverpb.Lease/LeaseGrant",
    request.encode(),
    @moonetcd.LeaseGrantResponse::decode,
  )
}

///|
/// Revoke the lease `id`; all keys attached to it are deleted.
pub async fn Lease::revoke(
  self : Lease,
  id : Int64,
) -> LeaseRevokeResponse raise EtcdError {
  let request = @moonetcd.LeaseRevokeRequest::{ id, }
  self.client.rpc(
    "/etcdserverpb.Lease/LeaseRevoke",
    request.encode(),
    @moonetcd.LeaseRevokeResponse::decode,
  )
}

///|
/// Inspect lease `id`: its remaining TTL, the granted TTL, and (with `keys`) the keys
/// it guards.
pub async fn Lease::time_to_live(
  self : Lease,
  id : Int64,
  keys? : Bool,
) -> LeaseTimeToLiveResponse raise EtcdError {
  let request = @moonetcd.LeaseTimeToLiveRequest::{
    id,
    keys: keys.unwrap_or(false),
  }
  self.client.rpc(
    "/etcdserverpb.Lease/LeaseTimeToLive",
    request.encode(),
    @moonetcd.LeaseTimeToLiveResponse::decode,
  )
}

///|
/// List every lease id currently known to the cluster.
pub async fn Lease::leases(self : Lease) -> LeaseLeasesResponse raise EtcdError {
  // LeaseLeasesRequest is the empty message, so an empty body is a valid request.
  self.client.rpc(
    "/etcdserverpb.Lease/LeaseLeases",
    b"",
    @moonetcd.LeaseLeasesResponse::decode,
  )
}

///|
/// A live KeepAlive session. Open it with `keep_alive`, ask it to hold leases with
/// `keep_alive(id)`, drain acknowledgements with `next`, and close it with `close`.
pub struct KeepAlive {
  stream : &KeepAliveStream
}

///|
/// Open the keep-alive session. `g` is the task group that carries the stream's
/// background work, so this — like `Watch::watch_create` — must run inside
/// `@async.with_task_group`.
pub async fn Lease::keep_alive(
  self : Lease,
  g : @async.TaskGroup[Unit],
) -> KeepAlive raise EtcdError {
  { stream: self.client.keep_alive_stream(g), }
}

///|
/// Ask the server to keep `id` alive for another period.
pub async fn KeepAlive::keep_alive(
  self : KeepAlive,
  id : Int64,
) -> Unit raise EtcdError {
  self.stream.keep_alive(id)
}

///|
/// The next acknowledgement, or `None` when the session has ended.
pub async fn KeepAlive::next(
  self : KeepAlive,
) -> LeaseKeepAliveResponse? raise EtcdError {
  self.stream.next()
}

///|
/// End the session and release its connection.
pub fn KeepAlive::close(self : KeepAlive) -> Unit {
  self.stream.close()
}
