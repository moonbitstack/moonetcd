// The leadership election service (`v3election`): campaign for leadership, proclaim a
// value, observe the current leader, and resign. Field numbers follow etcd's
// `election.proto`.

///|
/// The opaque handle to a leadership claim (`v3election.LeaderKey`).
#derive(Eq)
pub(all) struct LeaderKey {
  name : Bytes
  key : Bytes
  rev : Int64
  lease : Int64
}

///|
pub extend LeaderKey with Eq::{not_equal, equal}

///|
pub fn LeaderKey::empty() -> LeaderKey {
  { name: b"", key: b"", rev: 0, lease: 0, }
}

///|
pub fn LeaderKey::encode(self : LeaderKey) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.name.length() > 0 {
    w.bytes_(1, self.name)
  }
  if self.key.length() > 0 {
    w.bytes_(2, self.key)
  }
  if self.rev != 0 {
    w.int64(3, self.rev)
  }
  if self.lease != 0 {
    w.int64(4, self.lease)
  }
  w.to_bytes()
}

///|
pub fn LeaderKey::decode(data : Bytes) -> LeaderKey raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut k = LeaderKey::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => k = { ..k, name: r.read_bytes(), }
      (2, LengthDelim) => k = { ..k, key: r.read_bytes(), }
      (3, Varint) => k = { ..k, rev: r.read_int64(), }
      (4, Varint) => k = { ..k, lease: r.read_int64(), }
      (_, wire) => r.skip(wire)
    }
  }
  k
}

///|
/// Enter the election `name` with `value`, guarded by `lease`
/// (`v3election.CampaignRequest`).
#derive(Eq)
pub(all) struct CampaignRequest {
  name : Bytes
  value : Bytes
  lease : Int64
}

///|
pub extend CampaignRequest with Eq::{not_equal, equal}

///|
pub fn CampaignRequest::empty() -> CampaignRequest {
  { name: b"", value: b"", lease: 0, }
}

///|
pub fn CampaignRequest::encode(self : CampaignRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.name.length() > 0 {
    w.bytes_(1, self.name)
  }
  if self.lease != 0 {
    w.int64(2, self.lease)
  }
  if self.value.length() > 0 {
    w.bytes_(3, self.value)
  }
  w.to_bytes()
}

///|
pub fn CampaignRequest::decode(
  data : Bytes,
) -> CampaignRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = CampaignRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => req = { ..req, name: r.read_bytes(), }
      (2, Varint) => req = { ..req, lease: r.read_int64(), }
      (3, LengthDelim) => req = { ..req, value: r.read_bytes(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn CampaignResponse::empty() -> CampaignResponse {
  { header: ResponseHeader::empty(), leader: LeaderKey::empty(), }
}

///|
/// The won leadership (`v3election.CampaignResponse`).
#derive(Eq)
pub(all) struct CampaignResponse {
  header : ResponseHeader
  leader : LeaderKey
}

///|
pub extend CampaignResponse with Eq::{not_equal, equal}

///|
pub fn CampaignResponse::encode(self : CampaignResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  if self.leader != LeaderKey::empty() {
    w.message_(2, self.leader.encode())
  }
  w.to_bytes()
}

///|
pub fn CampaignResponse::decode(
  data : Bytes,
) -> CampaignResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut resp = CampaignResponse::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) =>
        resp = { ..resp, header: ResponseHeader::decode(r.read_bytes()), }
      (2, LengthDelim) =>
        resp = { ..resp, leader: LeaderKey::decode(r.read_bytes()), }
      (_, wire) => r.skip(wire)
    }
  }
  resp
}

///|
/// Ask for the current leader of election `name` (`v3election.LeaderRequest`).
#derive(Eq)
pub(all) struct LeaderRequest {
  name : Bytes
}

///|
pub extend LeaderRequest with Eq::{not_equal, equal}

///|
pub fn LeaderRequest::empty() -> LeaderRequest {
  { name: b"", }
}

///|
pub fn LeaderRequest::encode(self : LeaderRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.name.length() > 0 {
    w.bytes_(1, self.name)
  }
  w.to_bytes()
}

///|
pub fn LeaderRequest::decode(
  data : Bytes,
) -> LeaderRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = LeaderRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => req = { name: r.read_bytes(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn LeaderResponse::empty() -> LeaderResponse {
  { header: ResponseHeader::empty(), kv: KeyValue::empty(), }
}

///|
/// The current leader (`v3election.LeaderResponse`).
#derive(Eq)
pub(all) struct LeaderResponse {
  header : ResponseHeader
  kv : KeyValue
}

///|
pub extend LeaderResponse with Eq::{not_equal, equal}

///|
pub fn LeaderResponse::encode(self : LeaderResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  if self.kv != KeyValue::empty() {
    w.message_(2, self.kv.encode())
  }
  w.to_bytes()
}

///|
pub fn LeaderResponse::decode(
  data : Bytes,
) -> LeaderResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut resp = LeaderResponse::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) =>
        resp = { ..resp, header: ResponseHeader::decode(r.read_bytes()), }
      (2, LengthDelim) =>
        resp = { ..resp, kv: KeyValue::decode(r.read_bytes()), }
      (_, wire) => r.skip(wire)
    }
  }
  resp
}

///|
/// Update the value of a held leadership (`v3election.ProclaimRequest`).
#derive(Eq)
pub(all) struct ProclaimRequest {
  leader : LeaderKey
  value : Bytes
}

///|
pub extend ProclaimRequest with Eq::{not_equal, equal}

///|
pub fn ProclaimRequest::empty() -> ProclaimRequest {
  { leader: LeaderKey::empty(), value: b"", }
}

///|
pub fn ProclaimRequest::encode(self : ProclaimRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.leader != LeaderKey::empty() {
    w.message_(1, self.leader.encode())
  }
  if self.value.length() > 0 {
    w.bytes_(2, self.value)
  }
  w.to_bytes()
}

///|
pub fn ProclaimRequest::decode(
  data : Bytes,
) -> ProclaimRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = ProclaimRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) =>
        req = { ..req, leader: LeaderKey::decode(r.read_bytes()), }
      (2, LengthDelim) => req = { ..req, value: r.read_bytes(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn ProclaimResponse::empty() -> ProclaimResponse {
  { header: ResponseHeader::empty(), }
}

///|
/// The reply to a proclaim (`v3election.ProclaimResponse`): just the header.
#derive(Eq)
pub(all) struct ProclaimResponse {
  header : ResponseHeader
}

///|
pub extend ProclaimResponse with Eq::{not_equal, equal}

///|
pub fn ProclaimResponse::encode(self : ProclaimResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  w.to_bytes()
}

///|
pub fn ProclaimResponse::decode(
  data : Bytes,
) -> ProclaimResponse raise @proto.PbError {
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
/// Give up a held leadership (`v3election.ResignRequest`).
#derive(Eq)
pub(all) struct ResignRequest {
  leader : LeaderKey
}

///|
pub extend ResignRequest with Eq::{not_equal, equal}

///|
pub fn ResignRequest::empty() -> ResignRequest {
  { leader: LeaderKey::empty(), }
}

///|
pub fn ResignRequest::encode(self : ResignRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.leader != LeaderKey::empty() {
    w.message_(1, self.leader.encode())
  }
  w.to_bytes()
}

///|
pub fn ResignRequest::decode(
  data : Bytes,
) -> ResignRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = ResignRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => req = { leader: LeaderKey::decode(r.read_bytes()), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn ResignResponse::empty() -> ResignResponse {
  { header: ResponseHeader::empty(), }
}

///|
/// Resign reply (`v3election.ResignResponse`).
#derive(Eq)
pub(all) struct ResignResponse {
  header : ResponseHeader
}

///|
pub extend ResignResponse with Eq::{not_equal, equal}

///|
pub fn ResignResponse::encode(self : ResignResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  w.to_bytes()
}

///|
pub fn ResignResponse::decode(
  data : Bytes,
) -> ResignResponse raise @proto.PbError {
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
