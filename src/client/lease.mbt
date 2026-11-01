// Lease: grant, revoke, TimeToLive, list, and KeepAlive (a bidi stream over a
// dedicated multiplexed channel so it never disturbs the unary path).

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
  let req = @moonetcd.LeaseGrantRequest::{ ttl, id: id.unwrap_or(0), }
  self.client.rpc(
    "/etcdserverpb.Lease/LeaseGrant",
    req.encode(),
    @moonetcd.LeaseGrantResponse::decode,
  )
}

///|
/// Revoke the lease `id`; all keys attached to it are deleted.
pub async fn Lease::revoke(
  self : Lease,
  id : Int64,
) -> LeaseRevokeResponse raise EtcdError {
  let req = @moonetcd.LeaseRevokeRequest::{ id, }
  self.client.rpc(
    "/etcdserverpb.Lease/LeaseRevoke",
    req.encode(),
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
  let req = @moonetcd.LeaseTimeToLiveRequest::{
    id,
    keys: keys.unwrap_or(false),
  }
  self.client.rpc(
    "/etcdserverpb.Lease/LeaseTimeToLive",
    req.encode(),
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
/// A live KeepAlive stream. Open it with `keep_alive`, send `keep_alive(id)` for every
/// lease to hold, and drain responses with `next`. Close it with `close`.
pub struct KeepAlive {
  client : Client
  mux : @net.MuxChannel
  bidi : @net.BidiStream
}

///|
/// Open the KeepAlive bidi stream. `g` is the task group that drives the channel's read
/// pump, so this — like `Watch::watch_create` — must run inside `@async.with_task_group`.
pub async fn Lease::keep_alive(
  self : Lease,
  g : @async.TaskGroup[Unit],
) -> KeepAlive raise EtcdError {
  let ep = self.client.endpoint_at(0)
  let mux = @net.MuxChannel::connect(ep.0, ep.1) catch {
    _ => raise transport_error("keepalive dial")
  }
  g.spawn_bg(no_wait=true, () => mux.read_pump())
  @async.sleep(1)
  let bidi = mux.open_bidi("/etcdserverpb.Lease/LeaseKeepAlive")
  KeepAlive::{ client: self.client, mux, bidi, }
}

///|
/// Ask the server to keep `lease_id` alive.
pub async fn KeepAlive::keep_alive(
  self : KeepAlive,
  lease_id : Int64,
) -> Unit raise EtcdError {
  self.bidi.send(@moonetcd.LeaseKeepAliveRequest::{ id: lease_id, }.encode()) catch {
    _ => raise transport_error("keepalive send")
  }
}

///|
/// The next KeepAlive acknowledgement, or `None` when the stream has ended.
pub async fn KeepAlive::next(
  self : KeepAlive,
) -> LeaseKeepAliveResponse? raise EtcdError {
  let raw = self.bidi.recv() catch {
    _ => raise transport_error("keepalive recv")
  }
  match raw {
    Some(bytes) => {
      let r = @moonetcd.LeaseKeepAliveResponse::decode(bytes) catch {
        _ =>
          raise @moonetcd.EtcdError::Refused(@moonetcd.Status::{
            code: 13,
            message: "decode KeepAliveResponse failed",
          })
      }
      Some(r)
    }
    None => None
  }
}

///|
/// End the KeepAlive stream and close its connection.
pub fn KeepAlive::close(self : KeepAlive) -> Unit {
  self.mux.close()
}
