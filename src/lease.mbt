// The Lease service (`etcdserverpb`): grant, revoke, renew (keep alive), inspect, and
// list. Field numbers follow etcd's `lease.proto`.

///|
/// Ask etcd for a lease living `ttl` seconds, with a caller-chosen `id`
/// (`etcdserverpb.LeaseGrantRequest`). `id` 0 lets the server assign one.
#derive(Eq)
pub(all) struct LeaseGrantRequest {
  ttl : Int64
  id : Int64
}

///|
pub extend LeaseGrantRequest with Eq::{not_equal, equal}

///|
pub fn LeaseGrantRequest::empty() -> LeaseGrantRequest {
  { ttl: 0, id: 0, }
}

///|
pub fn LeaseGrantRequest::encode(self : LeaseGrantRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.ttl != 0 {
    w.int64(1, self.ttl)
  }
  if self.id != 0 {
    w.int64(2, self.id)
  }
  w.to_bytes()
}

///|
pub fn LeaseGrantRequest::decode(
  data : Bytes,
) -> LeaseGrantRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = LeaseGrantRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, Varint) => req = { ..req, ttl: r.read_int64(), }
      (2, Varint) => req = { ..req, id: r.read_int64(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn LeaseGrantResponse::empty() -> LeaseGrantResponse {
  { header: ResponseHeader::empty(), id: 0, ttl: 0, error: "", }
}

///|
/// The granted lease (`etcdserverpb.LeaseGrantResponse`). `error` is non-empty when
/// the grant failed.
#derive(Eq)
pub(all) struct LeaseGrantResponse {
  header : ResponseHeader
  id : Int64
  ttl : Int64
  error : String
}

///|
pub extend LeaseGrantResponse with Eq::{not_equal, equal}

///|
pub fn LeaseGrantResponse::encode(self : LeaseGrantResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  if self.id != 0 {
    w.int64(2, self.id)
  }
  if self.ttl != 0 {
    w.int64(3, self.ttl)
  }
  if self.error.length() > 0 {
    w.string_(4, self.error)
  }
  w.to_bytes()
}

///|
pub fn LeaseGrantResponse::decode(
  data : Bytes,
) -> LeaseGrantResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut resp = LeaseGrantResponse::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) =>
        resp = { ..resp, header: ResponseHeader::decode(r.read_bytes()), }
      (2, Varint) => resp = { ..resp, id: r.read_int64(), }
      (3, Varint) => resp = { ..resp, ttl: r.read_int64(), }
      (4, LengthDelim) => resp = { ..resp, error: r.read_string(), }
      (_, wire) => r.skip(wire)
    }
  }
  resp
}

///|
/// Revoke lease `id` (`etcdserverpb.LeaseRevokeRequest`).
#derive(Eq)
pub(all) struct LeaseRevokeRequest {
  id : Int64
}

///|
pub extend LeaseRevokeRequest with Eq::{not_equal, equal}

///|
pub fn LeaseRevokeRequest::empty() -> LeaseRevokeRequest {
  { id: 0, }
}

///|
pub fn LeaseRevokeRequest::encode(self : LeaseRevokeRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.id != 0 {
    w.int64(1, self.id)
  }
  w.to_bytes()
}

///|
pub fn LeaseRevokeRequest::decode(
  data : Bytes,
) -> LeaseRevokeRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = LeaseRevokeRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, Varint) => req = { id: r.read_int64(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn LeaseRevokeResponse::empty() -> LeaseRevokeResponse {
  { header: ResponseHeader::empty(), }
}

///|
/// The result of a revoke (`etcdserverpb.LeaseRevokeResponse`).
#derive(Eq)
pub(all) struct LeaseRevokeResponse {
  header : ResponseHeader
}

///|
pub extend LeaseRevokeResponse with Eq::{not_equal, equal}

///|
pub fn LeaseRevokeResponse::encode(self : LeaseRevokeResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  w.to_bytes()
}

///|
pub fn LeaseRevokeResponse::decode(
  data : Bytes,
) -> LeaseRevokeResponse raise @proto.PbError {
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
/// Renew lease `id` (`etcdserverpb.LeaseKeepAliveRequest`).
#derive(Eq)
pub(all) struct LeaseKeepAliveRequest {
  id : Int64
}

///|
pub extend LeaseKeepAliveRequest with Eq::{not_equal, equal}

///|
pub fn LeaseKeepAliveRequest::empty() -> LeaseKeepAliveRequest {
  { id: 0, }
}

///|
pub fn LeaseKeepAliveRequest::encode(self : LeaseKeepAliveRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.id != 0 {
    w.int64(1, self.id)
  }
  w.to_bytes()
}

///|
pub fn LeaseKeepAliveRequest::decode(
  data : Bytes,
) -> LeaseKeepAliveRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = LeaseKeepAliveRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, Varint) => req = { id: r.read_int64(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn LeaseKeepAliveResponse::empty() -> LeaseKeepAliveResponse {
  { header: ResponseHeader::empty(), id: 0, ttl: 0, }
}

///|
/// The renewed lease and its remaining `ttl` (`etcdserverpb.LeaseKeepAliveResponse`).
/// A `ttl` of 0 means the lease has expired.
#derive(Eq)
pub(all) struct LeaseKeepAliveResponse {
  header : ResponseHeader
  id : Int64
  ttl : Int64
}

///|
pub extend LeaseKeepAliveResponse with Eq::{not_equal, equal}

///|
pub fn LeaseKeepAliveResponse::encode(self : LeaseKeepAliveResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  if self.id != 0 {
    w.int64(2, self.id)
  }
  if self.ttl != 0 {
    w.int64(3, self.ttl)
  }
  w.to_bytes()
}

///|
pub fn LeaseKeepAliveResponse::decode(
  data : Bytes,
) -> LeaseKeepAliveResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut resp = LeaseKeepAliveResponse::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) =>
        resp = { ..resp, header: ResponseHeader::decode(r.read_bytes()), }
      (2, Varint) => resp = { ..resp, id: r.read_int64(), }
      (3, Varint) => resp = { ..resp, ttl: r.read_int64(), }
      (_, wire) => r.skip(wire)
    }
  }
  resp
}

///|
/// Inspect lease `id`, optionally listing the keys attached to it
/// (`etcdserverpb.LeaseTimeToLiveRequest`).
#derive(Eq)
pub(all) struct LeaseTimeToLiveRequest {
  id : Int64
  keys : Bool
}

///|
pub extend LeaseTimeToLiveRequest with Eq::{not_equal, equal}

///|
pub fn LeaseTimeToLiveRequest::empty() -> LeaseTimeToLiveRequest {
  { id: 0, keys: false, }
}

///|
pub fn LeaseTimeToLiveRequest::encode(self : LeaseTimeToLiveRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.id != 0 {
    w.int64(1, self.id)
  }
  if self.keys {
    w.bool_(2, self.keys)
  }
  w.to_bytes()
}

///|
pub fn LeaseTimeToLiveRequest::decode(
  data : Bytes,
) -> LeaseTimeToLiveRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = LeaseTimeToLiveRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, Varint) => req = { ..req, id: r.read_int64(), }
      (2, Varint) => req = { ..req, keys: r.read_bool(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn LeaseTimeToLiveResponse::empty() -> LeaseTimeToLiveResponse {
  { header: ResponseHeader::empty(), id: 0, ttl: 0, granted_ttl: 0, keys: [], }
}

///|
/// A lease's remaining time (`etcdserverpb.LeaseTimeToLiveResponse`).
#derive(Eq)
pub(all) struct LeaseTimeToLiveResponse {
  header : ResponseHeader
  id : Int64
  ttl : Int64
  granted_ttl : Int64
  keys : Array[Bytes]
}

///|
pub extend LeaseTimeToLiveResponse with Eq::{not_equal, equal}

///|
pub fn LeaseTimeToLiveResponse::encode(self : LeaseTimeToLiveResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  if self.id != 0 {
    w.int64(2, self.id)
  }
  if self.ttl != 0 {
    w.int64(3, self.ttl)
  }
  if self.granted_ttl != 0 {
    w.int64(4, self.granted_ttl)
  }
  for k in self.keys {
    w.bytes_(5, k)
  }
  w.to_bytes()
}

///|
pub fn LeaseTimeToLiveResponse::decode(
  data : Bytes,
) -> LeaseTimeToLiveResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut resp = LeaseTimeToLiveResponse::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) =>
        resp = { ..resp, header: ResponseHeader::decode(r.read_bytes()), }
      (2, Varint) => resp = { ..resp, id: r.read_int64(), }
      (3, Varint) => resp = { ..resp, ttl: r.read_int64(), }
      (4, Varint) => resp = { ..resp, granted_ttl: r.read_int64(), }
      (5, LengthDelim) => resp.keys.push(r.read_bytes())
      (_, wire) => r.skip(wire)
    }
  }
  resp
}

///|
/// One lease's id (`etcdserverpb.LeaseStatus`).
#derive(Eq)
pub(all) struct LeaseStatus {
  id : Int64
}

///|
pub extend LeaseStatus with Eq::{not_equal, equal}

///|
pub fn LeaseStatus::empty() -> LeaseStatus {
  { id: 0, }
}

///|
pub fn LeaseStatus::encode(self : LeaseStatus) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.id != 0 {
    w.int64(1, self.id)
  }
  w.to_bytes()
}

///|
pub fn LeaseStatus::decode(data : Bytes) -> LeaseStatus raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut s = LeaseStatus::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, Varint) => s = { id: r.read_int64(), }
      (_, wire) => r.skip(wire)
    }
  }
  s
}

///|
pub fn LeaseLeasesResponse::empty() -> LeaseLeasesResponse {
  { header: ResponseHeader::empty(), leases: [], }
}

///|
/// The list of leases (`etcdserverpb.LeaseLeasesResponse`).
#derive(Eq)
pub(all) struct LeaseLeasesResponse {
  header : ResponseHeader
  leases : Array[LeaseStatus]
}

///|
pub extend LeaseLeasesResponse with Eq::{not_equal, equal}

///|
pub fn LeaseLeasesResponse::encode(self : LeaseLeasesResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  for l in self.leases {
    w.message_(2, l.encode())
  }
  w.to_bytes()
}

///|
pub fn LeaseLeasesResponse::decode(
  data : Bytes,
) -> LeaseLeasesResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut resp = LeaseLeasesResponse::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) =>
        resp = { ..resp, header: ResponseHeader::decode(r.read_bytes()), }
      (2, LengthDelim) => resp.leases.push(LeaseStatus::decode(r.read_bytes()))
      (_, wire) => r.skip(wire)
    }
  }
  resp
}
