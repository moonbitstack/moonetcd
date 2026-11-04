// The Cluster service (`etcdserverpb`): membership of the etcd cluster. Field numbers
// follow etcd's `rpc.proto`.

///|
/// One member of the cluster (`etcdserverpb.Member`).
#derive(Eq)
pub(all) struct Member {
  id : UInt64
  name : String
  peer_urls : Array[String]
  client_urls : Array[String]
}

///|
pub extend Member with Eq::{not_equal, equal}

///|
pub fn Member::empty() -> Member {
  { id: 0, name: "", peer_urls: [], client_urls: [], }
}

///|
pub fn Member::encode(self : Member) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.id != 0 {
    w.uint64(1, self.id)
  }
  if self.name.length() > 0 {
    w.string_(2, self.name)
  }
  for u in self.peer_urls {
    w.string_(3, u)
  }
  for u in self.client_urls {
    w.string_(4, u)
  }
  w.to_bytes()
}

///|
pub fn Member::decode(data : Bytes) -> Member raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut m = Member::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, Varint) => m = { ..m, id: r.read_uint64(), }
      (2, LengthDelim) => m = { ..m, name: r.read_string(), }
      (3, LengthDelim) => m.peer_urls.push(r.read_string())
      (4, LengthDelim) => m.client_urls.push(r.read_string())
      (_, wire) => r.skip(wire)
    }
  }
  m
}

///|
/// Add a member with the given peer URLs (`etcdserverpb.MemberAddRequest`).
#derive(Eq)
pub(all) struct MemberAddRequest {
  peer_urls : Array[String]
  is_learner : Bool
}

///|
pub extend MemberAddRequest with Eq::{not_equal, equal}

///|
pub fn MemberAddRequest::empty() -> MemberAddRequest {
  { peer_urls: [], is_learner: false, }
}

///|
pub fn MemberAddRequest::encode(self : MemberAddRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  for u in self.peer_urls {
    w.string_(1, u)
  }
  if self.is_learner {
    w.bool_(2, self.is_learner)
  }
  w.to_bytes()
}

///|
pub fn MemberAddRequest::decode(
  data : Bytes,
) -> MemberAddRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = MemberAddRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => req.peer_urls.push(r.read_string())
      (2, Varint) => req = { ..req, is_learner: r.read_bool(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn MemberAddResponse::empty() -> MemberAddResponse {
  { header: ResponseHeader::empty(), member_: Member::empty(), members: [], }
}

///|
/// The added member and the resulting membership (`etcdserverpb.MemberAddResponse`).
#derive(Eq)
pub(all) struct MemberAddResponse {
  header : ResponseHeader
  member_ : Member
  members : Array[Member]
}

///|
pub extend MemberAddResponse with Eq::{not_equal, equal}

///|
pub fn MemberAddResponse::encode(self : MemberAddResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  if self.member_ != Member::empty() {
    w.message_(2, self.member_.encode())
  }
  for m in self.members {
    w.message_(3, m.encode())
  }
  w.to_bytes()
}

///|
pub fn MemberAddResponse::decode(
  data : Bytes,
) -> MemberAddResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut resp = MemberAddResponse::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) =>
        resp = { ..resp, header: ResponseHeader::decode(r.read_bytes()), }
      (2, LengthDelim) =>
        resp = { ..resp, member_: Member::decode(r.read_bytes()), }
      (3, LengthDelim) => resp.members.push(Member::decode(r.read_bytes()))
      (_, wire) => r.skip(wire)
    }
  }
  resp
}

///|
/// Remove the member `id` (`etcdserverpb.MemberRemoveRequest`).
#derive(Eq)
pub(all) struct MemberRemoveRequest {
  id : UInt64
}

///|
pub extend MemberRemoveRequest with Eq::{not_equal, equal}

///|
pub fn MemberRemoveRequest::empty() -> MemberRemoveRequest {
  { id: 0, }
}

///|
pub fn MemberRemoveRequest::encode(self : MemberRemoveRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.id != 0 {
    w.uint64(1, self.id)
  }
  w.to_bytes()
}

///|
pub fn MemberRemoveRequest::decode(
  data : Bytes,
) -> MemberRemoveRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = MemberRemoveRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, Varint) => req = { id: r.read_uint64(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn MemberRemoveResponse::empty() -> MemberRemoveResponse {
  { header: ResponseHeader::empty(), members: [], }
}

///|
/// The membership after a removal (`etcdserverpb.MemberRemoveResponse`).
#derive(Eq)
pub(all) struct MemberRemoveResponse {
  header : ResponseHeader
  members : Array[Member]
}

///|
pub extend MemberRemoveResponse with Eq::{not_equal, equal}

///|
pub fn MemberRemoveResponse::encode(self : MemberRemoveResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  for m in self.members {
    w.message_(2, m.encode())
  }
  w.to_bytes()
}

///|
pub fn MemberRemoveResponse::decode(
  data : Bytes,
) -> MemberRemoveResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut resp = MemberRemoveResponse::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) =>
        resp = { ..resp, header: ResponseHeader::decode(r.read_bytes()), }
      (2, LengthDelim) => resp.members.push(Member::decode(r.read_bytes()))
      (_, wire) => r.skip(wire)
    }
  }
  resp
}

///|
/// Change the peer URLs of member `id` (`etcdserverpb.MemberUpdateRequest`).
#derive(Eq)
pub(all) struct MemberUpdateRequest {
  id : UInt64
  peer_urls : Array[String]
}

///|
pub extend MemberUpdateRequest with Eq::{not_equal, equal}

///|
pub fn MemberUpdateRequest::empty() -> MemberUpdateRequest {
  { id: 0, peer_urls: [], }
}

///|
pub fn MemberUpdateRequest::encode(self : MemberUpdateRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.id != 0 {
    w.uint64(1, self.id)
  }
  for u in self.peer_urls {
    w.string_(2, u)
  }
  w.to_bytes()
}

///|
pub fn MemberUpdateRequest::decode(
  data : Bytes,
) -> MemberUpdateRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = MemberUpdateRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, Varint) => req = { ..req, id: r.read_uint64(), }
      (2, LengthDelim) => req.peer_urls.push(r.read_string())
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn MemberUpdateResponse::empty() -> MemberUpdateResponse {
  { header: ResponseHeader::empty(), members: [], }
}

///|
/// The membership after an update (`etcdserverpb.MemberUpdateResponse`).
#derive(Eq)
pub(all) struct MemberUpdateResponse {
  header : ResponseHeader
  members : Array[Member]
}

///|
pub extend MemberUpdateResponse with Eq::{not_equal, equal}

///|
pub fn MemberUpdateResponse::encode(self : MemberUpdateResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  for m in self.members {
    w.message_(2, m.encode())
  }
  w.to_bytes()
}

///|
pub fn MemberUpdateResponse::decode(
  data : Bytes,
) -> MemberUpdateResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut resp = MemberUpdateResponse::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) =>
        resp = { ..resp, header: ResponseHeader::decode(r.read_bytes()), }
      (2, LengthDelim) => resp.members.push(Member::decode(r.read_bytes()))
      (_, wire) => r.skip(wire)
    }
  }
  resp
}

///|
/// List the cluster members (`etcdserverpb.MemberListRequest`).
#derive(Eq)
pub(all) struct MemberListRequest {
  linearizable : Bool
}

///|
pub extend MemberListRequest with Eq::{not_equal, equal}

///|
pub fn MemberListRequest::empty() -> MemberListRequest {
  { linearizable: false, }
}

///|
pub fn MemberListRequest::encode(self : MemberListRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.linearizable {
    w.bool_(1, self.linearizable)
  }
  w.to_bytes()
}

///|
pub fn MemberListRequest::decode(
  data : Bytes,
) -> MemberListRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = MemberListRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, Varint) => req = { linearizable: r.read_bool(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn MemberListResponse::empty() -> MemberListResponse {
  { header: ResponseHeader::empty(), members: [], }
}

///|
/// The membership (`etcdserverpb.MemberListResponse`).
#derive(Eq)
pub(all) struct MemberListResponse {
  header : ResponseHeader
  members : Array[Member]
}

///|
pub extend MemberListResponse with Eq::{not_equal, equal}

///|
pub fn MemberListResponse::encode(self : MemberListResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  for m in self.members {
    w.message_(2, m.encode())
  }
  w.to_bytes()
}

///|
pub fn MemberListResponse::decode(
  data : Bytes,
) -> MemberListResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut resp = MemberListResponse::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) =>
        resp = { ..resp, header: ResponseHeader::decode(r.read_bytes()), }
      (2, LengthDelim) => resp.members.push(Member::decode(r.read_bytes()))
      (_, wire) => r.skip(wire)
    }
  }
  resp
}

///|
/// Promote a learner member `id` to a voting member
/// (`etcdserverpb.MemberPromoteRequest`).
#derive(Eq)
pub(all) struct MemberPromoteRequest {
  id : UInt64
}

///|
pub extend MemberPromoteRequest with Eq::{not_equal, equal}

///|
pub fn MemberPromoteRequest::empty() -> MemberPromoteRequest {
  { id: 0, }
}

///|
pub fn MemberPromoteRequest::encode(self : MemberPromoteRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.id != 0 {
    w.uint64(1, self.id)
  }
  w.to_bytes()
}

///|
pub fn MemberPromoteRequest::decode(
  data : Bytes,
) -> MemberPromoteRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = MemberPromoteRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, Varint) => req = { id: r.read_uint64(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn MemberPromoteResponse::empty() -> MemberPromoteResponse {
  { header: ResponseHeader::empty(), members: [], }
}

///|
/// The membership after a promotion (`etcdserverpb.MemberPromoteResponse`).
#derive(Eq)
pub(all) struct MemberPromoteResponse {
  header : ResponseHeader
  members : Array[Member]
}

///|
pub extend MemberPromoteResponse with Eq::{not_equal, equal}

///|
pub fn MemberPromoteResponse::encode(self : MemberPromoteResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  for m in self.members {
    w.message_(2, m.encode())
  }
  w.to_bytes()
}

///|
pub fn MemberPromoteResponse::decode(
  data : Bytes,
) -> MemberPromoteResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut resp = MemberPromoteResponse::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) =>
        resp = { ..resp, header: ResponseHeader::decode(r.read_bytes()), }
      (2, LengthDelim) => resp.members.push(Member::decode(r.read_bytes()))
      (_, wire) => r.skip(wire)
    }
  }
  resp
}
