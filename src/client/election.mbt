// Election: the v3election service — campaign for leadership of a named election,
// proclaim a value as the leader, read the current leader, and resign.

///|
/// A typed handle for the Election service. Obtain it with `client.election()`.
pub struct Election {
  client : Client
}

///|
/// Campaign for leadership of election `name`, carrying `value` and holding the
/// candidacy on `lease`. Blocks until `name` is won (or the lease dies).
pub async fn Election::campaign(
  self : Election,
  name : Bytes,
  value : Bytes,
  lease : Int64,
) -> CampaignResponse raise EtcdError {
  let req = @moonetcd.CampaignRequest::{ name, value, lease, }
  self.client.rpc(
    "/v3electionpb.Election/Campaign",
    req.encode(),
    @moonetcd.CampaignResponse::decode,
  )
}

///|
/// Proclaim `value` as the leader identified by `leader`.
pub async fn Election::proclaim(
  self : Election,
  leader : LeaderKey,
  value : Bytes,
) -> ProclaimResponse raise EtcdError {
  let req = @moonetcd.ProclaimRequest::{ leader, value, }
  self.client.rpc(
    "/v3electionpb.Election/Proclaim",
    req.encode(),
    @moonetcd.ProclaimResponse::decode,
  )
}

///|
/// The current leader of election `name`.
pub async fn Election::leader(
  self : Election,
  name : Bytes,
) -> LeaderResponse raise EtcdError {
  let req = @moonetcd.LeaderRequest::{ name, }
  self.client.rpc(
    "/v3electionpb.Election/Leader",
    req.encode(),
    @moonetcd.LeaderResponse::decode,
  )
}

///|
/// Resign the leadership identified by `leader`.
pub async fn Election::resign(
  self : Election,
  leader : LeaderKey,
) -> ResignResponse raise EtcdError {
  let req = @moonetcd.ResignRequest::{ leader, }
  self.client.rpc(
    "/v3electionpb.Election/Resign",
    req.encode(),
    @moonetcd.ResignResponse::decode,
  )
}
