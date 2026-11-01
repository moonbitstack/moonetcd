// Maintenance: cluster status, alarms, defragment, leader moves, and a snapshot
// (etcdserverpb.Maintenance). Snapshot is a server stream of blobs.

///|
/// A typed handle for the Maintenance service. Obtain it with `client.maintenance()`.
pub struct Maintenance {
  client : Client
}

///|
/// The status of the member this handle reaches: version, db size, leader, raft
/// indices, and any active alarms.
pub async fn Maintenance::status(
  self : Maintenance,
) -> StatusResponse raise EtcdError {
  self.client.rpc(
    "/etcdserverpb.Maintenance/Status",
    b"",
    @moonetcd.StatusResponse::decode,
  )
}

///|
/// Get, activate, or deactivate an alarm. `alarm` selects the alarm type; use `Get`
/// with `None` to read them all.
pub async fn Maintenance::alarm(
  self : Maintenance,
  action : AlarmAction,
  member_id : UInt64,
  alarm : AlarmType,
) -> AlarmResponse raise EtcdError {
  let req = @moonetcd.AlarmRequest::{ action, member_id, alarm, }
  self.client.rpc(
    "/etcdserverpb.Maintenance/Alarm",
    req.encode(),
    @moonetcd.AlarmResponse::decode,
  )
}

///|
/// Defragment the member's backend database.
pub async fn Maintenance::defragment(
  self : Maintenance,
) -> DefragmentResponse raise EtcdError {
  self.client.rpc(
    "/etcdserverpb.Maintenance/Defragment",
    b"",
    @moonetcd.DefragmentResponse::decode,
  )
}

///|
/// Transfer leadership of the cluster to member `target_id`.
pub async fn Maintenance::move_leader(
  self : Maintenance,
  target_id : UInt64,
) -> MoveLeaderResponse raise EtcdError {
  let req = @moonetcd.MoveLeaderRequest::{ target_id, }
  self.client.rpc(
    "/etcdserverpb.Maintenance/MoveLeader",
    req.encode(),
    @moonetcd.MoveLeaderResponse::decode,
  )
}

///|
/// Stream a point-in-time snapshot of the backend, returned as its ordered blobs. The
/// transport collects the whole stream, so this loads the snapshot into memory.
pub async fn Maintenance::snapshot(
  self : Maintenance,
) -> Array[SnapshotResponse] raise EtcdError {
  let blobs = self.client.rpc_stream("/etcdserverpb.Maintenance/Snapshot", b"")
  let out : Array[SnapshotResponse] = []
  for b in blobs {
    out.push(@moonetcd.SnapshotResponse::decode(b)) catch {
      _ =>
        raise @moonetcd.EtcdError::Refused(@moonetcd.Status::{
          code: 13,
          message: "decode SnapshotResponse failed",
        })
    }
  }
  out
}
