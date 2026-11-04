// The Watch service (`etcdserverpb`): a bidi stream of changes. `WatchRequest`'s
// `request_union` is a oneof, so it is an enum with hand-written wire code.

///|
/// What a watch filters out (`etcdserverpb.WatchCreateRequest.FilterType`).
#derive(Eq)
pub(all) enum FilterType {
  NoPut = 0
  NoDelete = 1
}

///|
pub extend FilterType with Eq::{not_equal, equal}

///|
pub fn FilterType::to_int(self : FilterType) -> Int32 {
  match self {
    NoPut => 0
    NoDelete => 1
  }
}

///|
pub fn FilterType::from_int(n : Int32) -> FilterType {
  if n == 1 {
    NoDelete
  } else {
    NoPut
  }
}

///|
/// Open a watch over `[key, range_end)` from `start_revision`
/// (`etcdserverpb.WatchCreateRequest`).
#derive(Eq)
pub(all) struct WatchCreateRequest {
  key : Bytes
  range_end : Bytes
  start_revision : Int64
  progress_notify : Bool
  filters : Array[FilterType]
  prev_kv : Bool
  watch_id : Int64
  fragment : Bool
}

///|
pub extend WatchCreateRequest with Eq::{not_equal, equal}

///|
pub fn WatchCreateRequest::empty() -> WatchCreateRequest {
  {
    key: b"",
    range_end: b"",
    start_revision: 0,
    progress_notify: false,
    filters: [],
    prev_kv: false,
    watch_id: 0,
    fragment: false,
  }
}

///|
pub fn WatchCreateRequest::encode(self : WatchCreateRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.key.length() > 0 {
    w.bytes_(1, self.key)
  }
  if self.range_end.length() > 0 {
    w.bytes_(2, self.range_end)
  }
  if self.start_revision != 0 {
    w.int64(3, self.start_revision)
  }
  if self.progress_notify {
    w.bool_(4, self.progress_notify)
  }
  for f in self.filters {
    w.enum_(5, f.to_int())
  }
  if self.prev_kv {
    w.bool_(6, self.prev_kv)
  }
  if self.watch_id != 0 {
    w.int64(7, self.watch_id)
  }
  if self.fragment {
    w.bool_(8, self.fragment)
  }
  w.to_bytes()
}

///|
pub fn WatchCreateRequest::decode(
  data : Bytes,
) -> WatchCreateRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = WatchCreateRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => req = { ..req, key: r.read_bytes(), }
      (2, LengthDelim) => req = { ..req, range_end: r.read_bytes(), }
      (3, Varint) => req = { ..req, start_revision: r.read_int64(), }
      (4, Varint) => req = { ..req, progress_notify: r.read_bool(), }
      (5, Varint) => req.filters.push(FilterType::from_int(r.read_int32()))
      (6, Varint) => req = { ..req, prev_kv: r.read_bool(), }
      (7, Varint) => req = { ..req, watch_id: r.read_int64(), }
      (8, Varint) => req = { ..req, fragment: r.read_bool(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
/// Close the watch `watch_id` (`etcdserverpb.WatchCancelRequest`).
#derive(Eq)
pub(all) struct WatchCancelRequest {
  watch_id : Int64
}

///|
pub extend WatchCancelRequest with Eq::{not_equal, equal}

///|
pub fn WatchCancelRequest::empty() -> WatchCancelRequest {
  { watch_id: 0, }
}

///|
pub fn WatchCancelRequest::encode(self : WatchCancelRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.watch_id != 0 {
    w.int64(1, self.watch_id)
  }
  w.to_bytes()
}

///|
pub fn WatchCancelRequest::decode(
  data : Bytes,
) -> WatchCancelRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = WatchCancelRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, Varint) => req = { watch_id: r.read_int64(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
/// Ask the server for a progress notification on an existing watch
/// (`etcdserverpb.WatchProgressRequest`).
#derive(Eq)
pub(all) struct WatchProgressRequest {}

///|
pub extend WatchProgressRequest with Eq::{not_equal, equal}

///|
pub fn WatchProgressRequest::encode(self : WatchProgressRequest) -> Bytes {
  let _ = self
  let w = @proto.PbWriter::new()
  w.to_bytes()
}

///|
pub fn WatchProgressRequest::decode(data : Bytes) -> WatchProgressRequest {
  let _ = data
  WatchProgressRequest::{ }
}

///|
/// One frame of the bidi Watch stream (`etcdserverpb.WatchRequest.request_union`).
#derive(Eq)
pub(all) enum WatchRequest {
  CreateRequest(WatchCreateRequest)
  CancelRequest(WatchCancelRequest)
  ProgressRequest(WatchProgressRequest)
}

///|
pub extend WatchRequest with Eq::{not_equal, equal}

///|
pub fn WatchRequest::encode(self : WatchRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  match self {
    CreateRequest(c) => w.message_(1, c.encode())
    CancelRequest(c) => w.message_(2, c.encode())
    ProgressRequest(p) => w.message_(3, p.encode())
  }
  w.to_bytes()
}

///|
pub fn WatchRequest::decode(data : Bytes) -> WatchRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut result : WatchRequest = CreateRequest(WatchCreateRequest::empty())
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) =>
        result = CreateRequest(WatchCreateRequest::decode(r.read_bytes()))
      (2, LengthDelim) =>
        result = CancelRequest(WatchCancelRequest::decode(r.read_bytes()))
      (3, LengthDelim) =>
        result = ProgressRequest(WatchProgressRequest::decode(r.read_bytes()))
      (_, wire) => r.skip(wire)
    }
  }
  result
}

///|
/// A frame the server sends on the Watch stream (`etcdserverpb.WatchResponse`): the
/// watch lifecycle flags and the batch of change `events` since the last frame.
#derive(Eq)
pub(all) struct WatchResponse {
  header : ResponseHeader
  watch_id : Int64
  created : Bool
  canceled : Bool
  events : Array[Event]
  compact_revision : Int64
  cancel_reason : String
  fragment : Bool
}

///|
pub extend WatchResponse with Eq::{not_equal, equal}

///|
pub fn WatchResponse::empty() -> WatchResponse {
  {
    header: ResponseHeader::empty(),
    watch_id: 0,
    created: false,
    canceled: false,
    events: [],
    compact_revision: 0,
    cancel_reason: "",
    fragment: false,
  }
}

///|
pub fn WatchResponse::encode(self : WatchResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  if self.watch_id != 0 {
    w.int64(2, self.watch_id)
  }
  if self.created {
    w.bool_(3, self.created)
  }
  if self.canceled {
    w.bool_(4, self.canceled)
  }
  for ev in self.events {
    w.message_(11, ev.encode())
  }
  if self.compact_revision != 0 {
    w.int64(5, self.compact_revision)
  }
  if self.cancel_reason.length() > 0 {
    w.string_(6, self.cancel_reason)
  }
  if self.fragment {
    w.bool_(7, self.fragment)
  }
  w.to_bytes()
}

///|
pub fn WatchResponse::decode(
  data : Bytes,
) -> WatchResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut resp = WatchResponse::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) =>
        resp = { ..resp, header: ResponseHeader::decode(r.read_bytes()), }
      (2, Varint) => resp = { ..resp, watch_id: r.read_int64(), }
      (3, Varint) => resp = { ..resp, created: r.read_bool(), }
      (4, Varint) => resp = { ..resp, canceled: r.read_bool(), }
      (11, LengthDelim) => resp.events.push(Event::decode(r.read_bytes()))
      (5, Varint) => resp = { ..resp, compact_revision: r.read_int64(), }
      (6, LengthDelim) => resp = { ..resp, cancel_reason: r.read_string(), }
      (7, Varint) => resp = { ..resp, fragment: r.read_bool(), }
      (_, wire) => r.skip(wire)
    }
  }
  resp
}

///|
/// Whether this answer is a progress notification: a revision with nothing else in it, which
/// is how the wire says so.
pub fn WatchResponse::is_progress_notify(self : WatchResponse) -> Bool {
  !self.created &&
  !self.canceled &&
  self.compact_revision == 0 &&
  self.events.is_empty()
}
