// Session: a lease plus a KeepAlive stream that a group of keys share. The lease
// keeps the keys alive while the caller drives `keepalive_once`; `close` revokes it,
// which deletes every key attached to it.

///|
/// A lease-backed session. Create it with `Session::new`; attach keys to
/// `lease_id()`, and call `close` to revoke it.
pub struct Session {
  client : @client.Client
  lease_id : Int64
  ttl : Int64
  ka : @client.KeepAlive
}

///|
/// Grant a lease of `ttl` seconds and open its KeepAlive stream. `g` is the task group
/// that drives the stream's read pump, so call this inside `@async.with_task_group`.
pub async fn Session::new(
  client : @client.Client,
  ttl : Int64,
  g : @async.TaskGroup[Unit],
) -> Session raise @client.EtcdError {
  let resp = client.lease().grant(ttl)
  let ka = client.lease().keep_alive(g)
  ka.keep_alive(resp.id)
  Session::{ client, lease_id: resp.id, ttl, ka, }
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
/// Read the next KeepAlive acknowledgement, returning `true` while the lease is still
/// alive. Drive it every TTL/3 seconds to keep the lease from expiring.
pub async fn Session::keepalive_once(
  self : Session,
) -> Bool raise @client.EtcdError {
  match self.ka.next() {
    Some(r) => r.ttl > 0
    None => false
  }
}

///|
/// Revoke the lease — deleting every key attached to it — and close the KeepAlive stream.
pub async fn Session::close(self : Session) -> Unit raise @client.EtcdError {
  self.ka.close()
  let _ = self.client.lease().revoke(self.lease_id)
}
