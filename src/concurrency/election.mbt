// Election: leader election over the v3election service. A candidate campaigns on a
// session's lease and, once it wins, can proclaim values and resign.

///|
/// A client-side election for `name`. Create it with `Election::new`, then
/// `campaign`, `proclaim`, and `resign`.
pub struct Election {
  client : @client.Client
  lease_id : Int64
  name : Bytes
  mut leader : @moonetcd.LeaderKey
}

///|
/// Build an election over `name`, campaigning on `session`'s lease.
pub fn Election::new(
  client : @client.Client,
  session : Session,
  name : Bytes,
) -> Election {
  Election::{
    client,
    lease_id: session.lease_id(),
    name,
    leader: @moonetcd.LeaderKey::empty(),
  }
}

///|
/// Campaign for leadership carrying `value`; blocks until `name` is won (or the lease
/// dies), then records the resulting leader key.
pub async fn Election::campaign(
  self : Election,
  value : Bytes,
) -> Unit raise @client.EtcdError {
  let resp = self.client.election().campaign(self.name, value, self.lease_id)
  self.leader = resp.leader
}

///|
/// Proclaim `value` as the current leader's.
pub async fn Election::proclaim(
  self : Election,
  value : Bytes,
) -> Unit raise @client.EtcdError {
  let _ = self.client.election().proclaim(self.leader, value)
}

///|
/// The current leader of the election.

///|
/// The current leader's key-value of the election.
pub async fn Election::current_leader(
  self : Election,
) -> @moonetcd.KeyValue raise @client.EtcdError {
  let resp = self.client.election().leader(self.name)
  resp.kv
}

///|
/// Resign the leadership.
pub async fn Election::resign(self : Election) -> Unit raise @client.EtcdError {
  let _ = self.client.election().resign(self.leader)
}
