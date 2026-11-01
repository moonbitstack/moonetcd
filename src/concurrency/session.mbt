// Session: a lease that a group of keys share. Granting the lease and revoking it are
// plain unary calls; keeping it alive is opt-in via `keep_alive`, which opens the
// KeepAlive stream on a task group only when a long-lived session needs it.

///|
/// A lease-backed session. Create it with `Session::new`; attach keys to `lease_id()`,
/// and call `close` to revoke it.
pub struct Session {
  client : @client.Client
  lease_id : Int64
  ttl : Int64
}

///|
/// Grant a lease of `ttl` seconds. For a long-lived session, also open `keep_alive` and
/// drive it so the lease does not expire.
pub async fn Session::new(
  client : @client.Client,
  ttl : Int64,
) -> Session raise @client.EtcdError {
  let resp = client.lease().grant(ttl)
  Session::{ client, lease_id: resp.id, ttl, }
}

///|
/// The lease id to attach keys to (via a Put's `lease` field).
pub fn Session::lease_id(self : Session) -> Int64 {
  self.lease_id
}

///|
/// The granted TTL, in seconds.
pub fn Session::ttl(self : Session) -> Int64 {
  self.ttl
}

///|
/// Open a KeepAlive stream for this lease. `g` is the task group that drives the
/// channel's read pump, so call this inside `@async.with_task_group`; then drive
/// `keep_alive`/`next` to hold the lease.
pub async fn Session::keep_alive(
  self : Session,
  g : @async.TaskGroup[Unit],
) -> @client.KeepAlive raise @client.EtcdError {
  let ka = self.client.lease().keep_alive(g)
  ka.keep_alive(self.lease_id)
  ka
}

///|
/// Revoke the lease — deleting every key attached to it.
pub async fn Session::close(self : Session) -> Unit raise @client.EtcdError {
  let _ = self.client.lease().revoke(self.lease_id)
}
