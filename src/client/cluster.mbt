// Cluster: membership of the etcd cluster (etcdserverpb.Cluster) — add, remove,
// update, list, and promote learners.

///|
/// A typed handle for the Cluster service. Obtain it with `client.cluster()`.
pub struct Cluster {
  client : Client
}

///|
/// Add a member with the given peer URLs; `is_learner` joins it as a non-voting learner.
pub async fn Cluster::member_add(
  self : Cluster,
  peer_urls : Array[String],
  is_learner? : Bool,
) -> MemberAddResponse raise EtcdError {
  let req = @moonetcd.MemberAddRequest::{
    peer_urls,
    is_learner: is_learner.unwrap_or(false),
  }
  self.client.rpc(
    "/etcdserverpb.Cluster/MemberAdd",
    req.encode(),
    @moonetcd.MemberAddResponse::decode,
  )
}

///|
/// Remove the member with id `id`.
pub async fn Cluster::member_remove(
  self : Cluster,
  id : UInt64,
) -> MemberRemoveResponse raise EtcdError {
  let req = @moonetcd.MemberRemoveRequest::{ id, }
  self.client.rpc(
    "/etcdserverpb.Cluster/MemberRemove",
    req.encode(),
    @moonetcd.MemberRemoveResponse::decode,
  )
}

///|
/// Replace member `id`'s peer URLs.
pub async fn Cluster::member_update(
  self : Cluster,
  id : UInt64,
  peer_urls : Array[String],
) -> MemberUpdateResponse raise EtcdError {
  let req = @moonetcd.MemberUpdateRequest::{ id, peer_urls, }
  self.client.rpc(
    "/etcdserverpb.Cluster/MemberUpdate",
    req.encode(),
    @moonetcd.MemberUpdateResponse::decode,
  )
}

///|
/// List every cluster member. `linearizable` reads through the leader.
pub async fn Cluster::member_list(
  self : Cluster,
  linearizable? : Bool,
) -> MemberListResponse raise EtcdError {
  let req = @moonetcd.MemberListRequest::{
    linearizable: linearizable.unwrap_or(false),
  }
  self.client.rpc(
    "/etcdserverpb.Cluster/MemberList",
    req.encode(),
    @moonetcd.MemberListResponse::decode,
  )
}

///|
/// Promote the learner `id` to a voting member.
pub async fn Cluster::member_promote(
  self : Cluster,
  id : UInt64,
) -> MemberPromoteResponse raise EtcdError {
  let req = @moonetcd.MemberPromoteRequest::{ id, }
  self.client.rpc(
    "/etcdserverpb.Cluster/MemberPromote",
    req.encode(),
    @moonetcd.MemberPromoteResponse::decode,
  )
}
