// The distributed lock service (`v3lock`): acquire a named lock, releasing it with
// the key etcd returned. Field numbers follow etcd's `lock.proto`.

///|
/// Acquire the lock named `name`; `lease` keeps it alive (`v3lock.LockRequest`).
#derive(Eq)
pub(all) struct LockRequest {
  name : Bytes
  lease : Int64
}

///|
pub extend LockRequest with Eq::{not_equal, equal}

///|
pub fn LockRequest::empty() -> LockRequest {
  { name: b"", lease: 0, }
}

///|
pub fn LockRequest::encode(self : LockRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.name.length() > 0 {
    w.bytes_(1, self.name)
  }
  if self.lease != 0 {
    w.int64(2, self.lease)
  }
  w.to_bytes()
}

///|
pub fn LockRequest::decode(data : Bytes) -> LockRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = LockRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => req = { ..req, name: r.read_bytes(), }
      (2, Varint) => req = { ..req, lease: r.read_int64(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn LockResponse::empty() -> LockResponse {
  { header: ResponseHeader::empty(), key: b"", }
}

///|
/// The lock is held while `key` exists (`v3lock.LockResponse`).
#derive(Eq)
pub(all) struct LockResponse {
  header : ResponseHeader
  key : Bytes
}

///|
pub extend LockResponse with Eq::{not_equal, equal}

///|
pub fn LockResponse::encode(self : LockResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  if self.key.length() > 0 {
    w.bytes_(2, self.key)
  }
  w.to_bytes()
}

///|
pub fn LockResponse::decode(data : Bytes) -> LockResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut resp = LockResponse::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) =>
        resp = { ..resp, header: ResponseHeader::decode(r.read_bytes()), }
      (2, LengthDelim) => resp = { ..resp, key: r.read_bytes(), }
      (_, wire) => r.skip(wire)
    }
  }
  resp
}

///|
/// Release the lock identified by `key` (`v3lock.UnlockRequest`).
#derive(Eq)
pub(all) struct UnlockRequest {
  key : Bytes
}

///|
pub extend UnlockRequest with Eq::{not_equal, equal}

///|
pub fn UnlockRequest::empty() -> UnlockRequest {
  { key: b"", }
}

///|
pub fn UnlockRequest::encode(self : UnlockRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.key.length() > 0 {
    w.bytes_(1, self.key)
  }
  w.to_bytes()
}

///|
pub fn UnlockRequest::decode(
  data : Bytes,
) -> UnlockRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = UnlockRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => req = { key: r.read_bytes(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn UnlockResponse::empty() -> UnlockResponse {
  { header: ResponseHeader::empty(), }
}

///|
/// The header of a released lock (`v3lock.UnlockResponse`).
#derive(Eq)
pub(all) struct UnlockResponse {
  header : ResponseHeader
}

///|
pub extend UnlockResponse with Eq::{not_equal, equal}

///|
pub fn UnlockResponse::encode(self : UnlockResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  w.to_bytes()
}

///|
pub fn UnlockResponse::decode(
  data : Bytes,
) -> UnlockResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut resp = UnlockResponse::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) =>
        resp = { header: ResponseHeader::decode(r.read_bytes()), }
      (_, wire) => r.skip(wire)
    }
  }
  resp
}
