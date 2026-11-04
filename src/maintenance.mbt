// The Maintenance service (`etcdserverpb`): cluster health, alarms, defragmentation,
// hashing, snapshots, leadership moves, and version downgrade. Field numbers follow
// etcd's `rpc.proto`.

///|
/// What an `AlarmRequest` does (`etcdserverpb.AlarmRequest.AlarmAction`).
#derive(Eq)
pub(all) enum AlarmAction {
  Get = 0
  Activate = 1
  Deactivate = 2
}

///|
pub extend AlarmAction with Eq::{not_equal, equal}

///|
pub fn AlarmAction::to_int(self : AlarmAction) -> Int32 {
  match self {
    Get => 0
    Activate => 1
    Deactivate => 2
  }
}

///|
pub fn AlarmAction::from_int(n : Int32) -> AlarmAction {
  if n == 1 {
    Activate
  } else if n == 2 {
    Deactivate
  } else {
    Get
  }
}

///|
/// The kind of alarm (`etcdserverpb.Alarm.Type`).
#derive(Eq)
pub(all) enum AlarmType {
  None = 0
  Nospace = 1
  Corrupt = 2
}

///|
pub extend AlarmType with Eq::{not_equal, equal}

///|
pub fn AlarmType::to_int(self : AlarmType) -> Int32 {
  match self {
    None => 0
    Nospace => 1
    Corrupt => 2
  }
}

///|
pub fn AlarmType::from_int(n : Int32) -> AlarmType {
  if n == 1 {
    Nospace
  } else if n == 2 {
    Corrupt
  } else {
    None
  }
}

///|
/// One raised alarm (`etcdserverpb.Alarm`).
#derive(Eq)
pub(all) struct Alarm {
  member_id : UInt64
  alarm : AlarmType
}

///|
pub extend Alarm with Eq::{not_equal, equal}

///|
pub fn Alarm::empty() -> Alarm {
  { member_id: 0, alarm: None, }
}

///|
pub fn Alarm::encode(self : Alarm) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.member_id != 0 {
    w.uint64(1, self.member_id)
  }
  if self.alarm.to_int() != 0 {
    w.enum_(2, self.alarm.to_int())
  }
  w.to_bytes()
}

///|
pub fn Alarm::decode(data : Bytes) -> Alarm raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut a = Alarm::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, Varint) => a = { ..a, member_id: r.read_uint64(), }
      (2, Varint) => a = { ..a, alarm: AlarmType::from_int(r.read_int32()), }
      (_, wire) => r.skip(wire)
    }
  }
  a
}

///|
/// Query or raise an alarm (`etcdserverpb.AlarmRequest`).
#derive(Eq)
pub(all) struct AlarmRequest {
  action : AlarmAction
  member_id : UInt64
  alarm : AlarmType
}

///|
pub extend AlarmRequest with Eq::{not_equal, equal}

///|
pub fn AlarmRequest::empty() -> AlarmRequest {
  { action: Get, member_id: 0, alarm: None, }
}

///|
pub fn AlarmRequest::encode(self : AlarmRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.action.to_int() != 0 {
    w.enum_(1, self.action.to_int())
  }
  if self.member_id != 0 {
    w.uint64(2, self.member_id)
  }
  if self.alarm.to_int() != 0 {
    w.enum_(3, self.alarm.to_int())
  }
  w.to_bytes()
}

///|
pub fn AlarmRequest::decode(data : Bytes) -> AlarmRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = AlarmRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, Varint) =>
        req = { ..req, action: AlarmAction::from_int(r.read_int32()), }
      (2, Varint) => req = { ..req, member_id: r.read_uint64(), }
      (3, Varint) =>
        req = { ..req, alarm: AlarmType::from_int(r.read_int32()), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn AlarmResponse::empty() -> AlarmResponse {
  { header: ResponseHeader::empty(), alarms: [], }
}

///|
/// The alarm state (`etcdserverpb.AlarmResponse`): a repeated list of alarms, each a
/// `memberID` and an `AlarmType`.
#derive(Eq)
pub(all) struct AlarmResponse {
  header : ResponseHeader
  alarms : Array[Alarm]
}

///|
pub extend AlarmResponse with Eq::{not_equal, equal}

///|
pub fn AlarmResponse::encode(self : AlarmResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  for a in self.alarms {
    w.message_(2, a.encode())
  }
  w.to_bytes()
}

///|
pub fn AlarmResponse::decode(
  data : Bytes,
) -> AlarmResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut header = ResponseHeader::empty()
  let alarms : Array[Alarm] = []
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => header = ResponseHeader::decode(r.read_bytes())
      (2, LengthDelim) => alarms.push(Alarm::decode(r.read_bytes()))
      (_, wire) => r.skip(wire)
    }
  }
  { header, alarms, }
}

///|
/// Snapshot of cluster state (`etcdserverpb.SnapshotRequest`).
#derive(Eq)
pub(all) struct SnapshotRequest {}

///|
pub extend SnapshotRequest with Eq::{not_equal, equal}

///|
pub fn SnapshotRequest::encode(self : SnapshotRequest) -> Bytes {
  let _ = self
  let w = @proto.PbWriter::new()
  w.to_bytes()
}

///|
pub fn SnapshotRequest::decode(data : Bytes) -> SnapshotRequest {
  let _ = data
  SnapshotRequest::{ }
}

///|
pub fn SnapshotResponse::empty() -> SnapshotResponse {
  { header: ResponseHeader::empty(), blob: b"", remaining_bytes: 0, }
}

///|
/// One chunk of a snapshot stream (`etcdserverpb.SnapshotResponse`).
#derive(Eq)
pub(all) struct SnapshotResponse {
  header : ResponseHeader
  blob : Bytes
  remaining_bytes : Int64
}

///|
pub extend SnapshotResponse with Eq::{not_equal, equal}

///|
pub fn SnapshotResponse::encode(self : SnapshotResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  if self.blob.length() > 0 {
    w.bytes_(3, self.blob)
  }
  if self.remaining_bytes != 0 {
    w.int64(2, self.remaining_bytes)
  }
  w.to_bytes()
}

///|
pub fn SnapshotResponse::decode(
  data : Bytes,
) -> SnapshotResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut resp = SnapshotResponse::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) =>
        resp = { ..resp, header: ResponseHeader::decode(r.read_bytes()), }
      (3, LengthDelim) => resp = { ..resp, blob: r.read_bytes(), }
      (2, Varint) => resp = { ..resp, remaining_bytes: r.read_int64(), }
      (_, wire) => r.skip(wire)
    }
  }
  resp
}

///|
/// A hash of the backend (`etcdserverpb.HashResponse`); `HashKV` pins a revision.
#derive(Eq)
pub(all) struct HashResponse {
  header : ResponseHeader
  hash : UInt32
}

///|
pub extend HashResponse with Eq::{not_equal, equal}

///|
pub fn HashResponse::empty() -> HashResponse {
  { header: ResponseHeader::empty(), hash: 0, }
}

///|
pub fn HashResponse::encode(self : HashResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  if self.hash != 0 {
    w.uint32(2, self.hash)
  }
  w.to_bytes()
}

///|
pub fn HashResponse::decode(data : Bytes) -> HashResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut resp = HashResponse::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) =>
        resp = { ..resp, header: ResponseHeader::decode(r.read_bytes()), }
      (2, Varint) => resp = { ..resp, hash: r.read_uint32(), }
      (_, wire) => r.skip(wire)
    }
  }
  resp
}

///|
pub fn HashKVResponse::empty() -> HashKVResponse {
  {
    header: ResponseHeader::empty(),
    hash: 0,
    compact_revision: 0,
    hash_revision: 0,
  }
}

///|
/// A hash of the backend at a pinned revision (`etcdserverpb.HashKVResponse`).
#derive(Eq)
pub(all) struct HashKVResponse {
  header : ResponseHeader
  hash : UInt32
  compact_revision : Int64
  hash_revision : Int64
}

///|
pub extend HashKVResponse with Eq::{not_equal, equal}

///|
pub fn HashKVResponse::encode(self : HashKVResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  if self.hash != 0 {
    w.uint32(2, self.hash)
  }
  if self.compact_revision != 0 {
    w.int64(3, self.compact_revision)
  }
  if self.hash_revision != 0 {
    w.int64(4, self.hash_revision)
  }
  w.to_bytes()
}

///|
pub fn HashKVResponse::decode(
  data : Bytes,
) -> HashKVResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut resp = HashKVResponse::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) =>
        resp = { ..resp, header: ResponseHeader::decode(r.read_bytes()), }
      (2, Varint) => resp = { ..resp, hash: r.read_uint32(), }
      (3, Varint) => resp = { ..resp, compact_revision: r.read_int64(), }
      (4, Varint) => resp = { ..resp, hash_revision: r.read_int64(), }
      (_, wire) => r.skip(wire)
    }
  }
  resp
}

///|
pub fn DefragmentResponse::empty() -> DefragmentResponse {
  { header: ResponseHeader::empty(), }
}

///|
/// The reply to a `Defragment` (`etcdserverpb.DefragmentResponse`).
#derive(Eq)
pub(all) struct DefragmentResponse {
  header : ResponseHeader
}

///|
pub extend DefragmentResponse with Eq::{not_equal, equal}

///|
pub fn DefragmentResponse::encode(self : DefragmentResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  w.to_bytes()
}

///|
pub fn DefragmentResponse::decode(
  data : Bytes,
) -> DefragmentResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut header = ResponseHeader::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => header = ResponseHeader::decode(r.read_bytes())
      (_, wire) => r.skip(wire)
    }
  }
  { header, }
}

///|
/// Cluster status (`etcdserverpb.StatusResponse`).
#derive(Eq)
pub(all) struct StatusResponse {
  header : ResponseHeader
  version : String
  db_size : Int64
  leader : UInt64
  raft_index : UInt64
  raft_term : UInt64
  raft_applied_index : UInt64
  errors : Array[Alarm]
  db_size_in_use : Int64
}

///|
pub extend StatusResponse with Eq::{not_equal, equal}

///|
pub fn StatusResponse::empty() -> StatusResponse {
  {
    header: ResponseHeader::empty(),
    version: "",
    db_size: 0,
    leader: 0,
    raft_index: 0,
    raft_term: 0,
    raft_applied_index: 0,
    errors: [],
    db_size_in_use: 0,
  }
}

///|
pub fn StatusResponse::encode(self : StatusResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  if self.version.length() > 0 {
    w.string_(2, self.version)
  }
  if self.db_size != 0 {
    w.int64(3, self.db_size)
  }
  if self.leader != 0 {
    w.uint64(4, self.leader)
  }
  if self.raft_index != 0 {
    w.uint64(5, self.raft_index)
  }
  if self.raft_term != 0 {
    w.uint64(6, self.raft_term)
  }
  if self.raft_applied_index != 0 {
    w.uint64(7, self.raft_applied_index)
  }
  for e in self.errors {
    w.message_(8, e.encode())
  }
  if self.db_size_in_use != 0 {
    w.int64(9, self.db_size_in_use)
  }
  w.to_bytes()
}

///|
pub fn StatusResponse::decode(
  data : Bytes,
) -> StatusResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut resp = StatusResponse::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) =>
        resp = { ..resp, header: ResponseHeader::decode(r.read_bytes()), }
      (2, LengthDelim) => resp = { ..resp, version: r.read_string(), }
      (3, Varint) => resp = { ..resp, db_size: r.read_int64(), }
      (4, Varint) => resp = { ..resp, leader: r.read_uint64(), }
      (5, Varint) => resp = { ..resp, raft_index: r.read_uint64(), }
      (6, Varint) => resp = { ..resp, raft_term: r.read_uint64(), }
      (7, Varint) => resp = { ..resp, raft_applied_index: r.read_uint64(), }
      (8, LengthDelim) => resp.errors.push(Alarm::decode(r.read_bytes()))
      (9, Varint) => resp = { ..resp, db_size_in_use: r.read_int64(), }
      (_, wire) => r.skip(wire)
    }
  }
  resp
}

///|
/// Move leadership to `target_id` (`etcdserverpb.MoveLeaderRequest`).
#derive(Eq)
pub(all) struct MoveLeaderRequest {
  target_id : UInt64
}

///|
pub extend MoveLeaderRequest with Eq::{not_equal, equal}

///|
pub fn MoveLeaderRequest::empty() -> MoveLeaderRequest {
  { target_id: 0, }
}

///|
pub fn MoveLeaderRequest::encode(self : MoveLeaderRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.target_id != 0 {
    w.uint64(1, self.target_id)
  }
  w.to_bytes()
}

///|
pub fn MoveLeaderRequest::decode(
  data : Bytes,
) -> MoveLeaderRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = MoveLeaderRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, Varint) => req = { target_id: r.read_uint64(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn MoveLeaderResponse::empty() -> MoveLeaderResponse {
  { header: ResponseHeader::empty(), }
}

///|
/// Move-leadership reply (`etcdserverpb.MoveLeaderResponse`).
#derive(Eq)
pub(all) struct MoveLeaderResponse {
  header : ResponseHeader
}

///|
pub extend MoveLeaderResponse with Eq::{not_equal, equal}

///|
pub fn MoveLeaderResponse::encode(self : MoveLeaderResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  w.to_bytes()
}

///|
pub fn MoveLeaderResponse::decode(
  data : Bytes,
) -> MoveLeaderResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut header = ResponseHeader::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => header = ResponseHeader::decode(r.read_bytes())
      (_, wire) => r.skip(wire)
    }
  }
  { header, }
}

///|
/// The downgrade step to take (`etcdserverpb.DowngradeRequest.DowngradeAction`).
#derive(Eq)
pub(all) enum DowngradeAction {
  Validate = 0
  Download = 1
  Cancel = 2
}

///|
pub extend DowngradeAction with Eq::{not_equal, equal}

///|
pub fn DowngradeAction::to_int(self : DowngradeAction) -> Int32 {
  match self {
    Validate => 0
    Download => 1
    Cancel => 2
  }
}

///|
pub fn DowngradeAction::from_int(n : Int32) -> DowngradeAction {
  if n == 1 {
    Download
  } else if n == 2 {
    Cancel
  } else {
    Validate
  }
}

///|
/// Start or cancel a cluster version downgrade (`etcdserverpb.DowngradeRequest`).
#derive(Eq)
pub(all) struct DowngradeRequest {
  action : DowngradeAction
  version : String
}

///|
pub extend DowngradeRequest with Eq::{not_equal, equal}

///|
pub fn DowngradeRequest::empty() -> DowngradeRequest {
  { action: Validate, version: "", }
}

///|
pub fn DowngradeRequest::encode(self : DowngradeRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.action.to_int() != 0 {
    w.enum_(1, self.action.to_int())
  }
  if self.version.length() > 0 {
    w.string_(2, self.version)
  }
  w.to_bytes()
}

///|
pub fn DowngradeRequest::decode(
  data : Bytes,
) -> DowngradeRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = DowngradeRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, Varint) =>
        req = { ..req, action: DowngradeAction::from_int(r.read_int32()), }
      (2, LengthDelim) => req = { ..req, version: r.read_string(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn DowngradeResponse::empty() -> DowngradeResponse {
  { header: ResponseHeader::empty(), version: "", }
}

///|
/// Downgrade state (`etcdserverpb.DowngradeResponse`).
#derive(Eq)
pub(all) struct DowngradeResponse {
  header : ResponseHeader
  version : String
}

///|
pub extend DowngradeResponse with Eq::{not_equal, equal}

///|
pub fn DowngradeResponse::encode(self : DowngradeResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  if self.version.length() > 0 {
    w.string_(2, self.version)
  }
  w.to_bytes()
}

///|
pub fn DowngradeResponse::decode(
  data : Bytes,
) -> DowngradeResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut resp = DowngradeResponse::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) =>
        resp = { ..resp, header: ResponseHeader::decode(r.read_bytes()), }
      (2, LengthDelim) => resp = { ..resp, version: r.read_string(), }
      (_, wire) => r.skip(wire)
    }
  }
  resp
}
