// The KV service (`etcdserverpb`): read, write, delete, a transactional batch, and
// compaction. Field numbers follow etcd's `rpc.proto` so the bytes match a real
// server. `Txn`'s `Compare` and the two `*Op` unions are oneofs, which the generator
// does not cover, so they are modelled as enums with hand-written wire code.

///|
/// Order of a ranged read (`etcdserverpb.RangeRequest.SortOrder`).
#derive(Eq)
pub(all) enum SortOrder {
  None = 0
  Ascend = 1
  Descend = 2
}

///|
pub extend SortOrder with Eq::{not_equal, equal}

///|
pub fn SortOrder::to_int(self : SortOrder) -> Int32 {
  match self {
    None => 0
    Ascend => 1
    Descend => 2
  }
}

///|
pub fn SortOrder::from_int(n : Int32) -> SortOrder {
  if n == 1 {
    Ascend
  } else if n == 2 {
    Descend
  } else {
    None
  }
}

///|
/// What a ranged read orders by (`etcdserverpb.RangeRequest.SortTarget`).
#derive(Eq)
pub(all) enum SortTarget {
  Key = 0
  Version = 1
  Create = 2
  Mod = 3
  Value = 4
}

///|
pub extend SortTarget with Eq::{not_equal, equal}

///|
pub fn SortTarget::to_int(self : SortTarget) -> Int32 {
  match self {
    Key => 0
    Version => 1
    Create => 2
    Mod => 3
    Value => 4
  }
}

///|
pub fn SortTarget::from_int(n : Int32) -> SortTarget {
  if n == 1 {
    Version
  } else if n == 2 {
    Create
  } else if n == 3 {
    Mod
  } else if n == 4 {
    Value
  } else {
    Key
  }
}

///|
/// Per-call metadata etcd returns with every response (`etcdserverpb.ResponseHeader`).
#derive(Eq)
pub(all) struct ResponseHeader {
  cluster_id : UInt64
  member_id : UInt64
  revision : Int64
  raft_term : UInt64
}

///|
pub extend ResponseHeader with Eq::{not_equal, equal}

///|
pub fn ResponseHeader::empty() -> ResponseHeader {
  { cluster_id: 0, member_id: 0, revision: 0, raft_term: 0, }
}

///|
pub fn ResponseHeader::encode(self : ResponseHeader) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.cluster_id != 0 {
    w.uint64(1, self.cluster_id)
  }
  if self.member_id != 0 {
    w.uint64(2, self.member_id)
  }
  if self.revision != 0 {
    w.int64(3, self.revision)
  }
  if self.raft_term != 0 {
    w.uint64(4, self.raft_term)
  }
  w.to_bytes()
}

///|
pub fn ResponseHeader::decode(
  data : Bytes,
) -> ResponseHeader raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut cluster_id = 0UL
  let mut member_id = 0UL
  let mut revision = 0L
  let mut raft_term = 0UL
  while !r.eof() {
    match r.read_tag() {
      (1, Varint) => cluster_id = r.read_uint64()
      (2, Varint) => member_id = r.read_uint64()
      (3, Varint) => revision = r.read_int64()
      (4, Varint) => raft_term = r.read_uint64()
      (_, wire) => r.skip(wire)
    }
  }
  { cluster_id, member_id, revision, raft_term, }
}

///|
/// A read over `[key, range_end)` (empty `range_end` is a single key), optionally
/// bounded, ordered, and pinned to a revision (`etcdserverpb.RangeRequest`).
#derive(Eq)
pub(all) struct RangeRequest {
  key : Bytes
  range_end : Bytes
  limit : Int64
  revision : Int64
  sort_order : SortOrder
  sort_target : SortTarget
  serializable : Bool
  keys_only : Bool
  count_only : Bool
  min_mod_revision : Int64
  max_mod_revision : Int64
  min_create_revision : Int64
  max_create_revision : Int64
}

///|
pub extend RangeRequest with Eq::{not_equal, equal}

///|
pub fn RangeRequest::empty() -> RangeRequest {
  {
    key: b"",
    range_end: b"",
    limit: 0,
    revision: 0,
    sort_order: None,
    sort_target: Key,
    serializable: false,
    keys_only: false,
    count_only: false,
    min_mod_revision: 0,
    max_mod_revision: 0,
    min_create_revision: 0,
    max_create_revision: 0,
  }
}

///|
pub fn RangeRequest::encode(self : RangeRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.key.length() > 0 {
    w.bytes_(1, self.key)
  }
  if self.range_end.length() > 0 {
    w.bytes_(2, self.range_end)
  }
  if self.limit != 0 {
    w.int64(3, self.limit)
  }
  if self.revision != 0 {
    w.int64(4, self.revision)
  }
  if self.sort_order.to_int() != 0 {
    w.enum_(5, self.sort_order.to_int())
  }
  if self.sort_target.to_int() != 0 {
    w.enum_(6, self.sort_target.to_int())
  }
  if self.serializable {
    w.bool_(7, self.serializable)
  }
  if self.keys_only {
    w.bool_(8, self.keys_only)
  }
  if self.count_only {
    w.bool_(9, self.count_only)
  }
  if self.min_mod_revision != 0 {
    w.int64(10, self.min_mod_revision)
  }
  if self.max_mod_revision != 0 {
    w.int64(11, self.max_mod_revision)
  }
  if self.min_create_revision != 0 {
    w.int64(12, self.min_create_revision)
  }
  if self.max_create_revision != 0 {
    w.int64(13, self.max_create_revision)
  }
  w.to_bytes()
}

///|
pub fn RangeRequest::decode(data : Bytes) -> RangeRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = RangeRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => req = { ..req, key: r.read_bytes(), }
      (2, LengthDelim) => req = { ..req, range_end: r.read_bytes(), }
      (3, Varint) => req = { ..req, limit: r.read_int64(), }
      (4, Varint) => req = { ..req, revision: r.read_int64(), }
      (5, Varint) =>
        req = { ..req, sort_order: SortOrder::from_int(r.read_int32()), }
      (6, Varint) =>
        req = { ..req, sort_target: SortTarget::from_int(r.read_int32()), }
      (7, Varint) => req = { ..req, serializable: r.read_bool(), }
      (8, Varint) => req = { ..req, keys_only: r.read_bool(), }
      (9, Varint) => req = { ..req, count_only: r.read_bool(), }
      (10, Varint) => req = { ..req, min_mod_revision: r.read_int64(), }
      (11, Varint) => req = { ..req, max_mod_revision: r.read_int64(), }
      (12, Varint) => req = { ..req, min_create_revision: r.read_int64(), }
      (13, Varint) => req = { ..req, max_create_revision: r.read_int64(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
/// The result of a `Range` (`etcdserverpb.RangeResponse`): the matched key/values,
/// whether more remain beyond `limit`, and the total count in the range.
#derive(Eq)
pub(all) struct RangeResponse {
  header : ResponseHeader
  kvs : Array[KeyValue]
  more : Bool
  count : Int64
}

///|
pub extend RangeResponse with Eq::{not_equal, equal}

///|
pub fn RangeResponse::empty() -> RangeResponse {
  { header: ResponseHeader::empty(), kvs: [], more: false, count: 0, }
}

///|
pub fn RangeResponse::encode(self : RangeResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  for kv in self.kvs {
    w.message_(2, kv.encode())
  }
  if self.more {
    w.bool_(3, self.more)
  }
  if self.count != 0 {
    w.int64(4, self.count)
  }
  w.to_bytes()
}

///|
pub fn RangeResponse::decode(
  data : Bytes,
) -> RangeResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut header = ResponseHeader::empty()
  let kvs : Array[KeyValue] = []
  let mut more = false
  let mut count = 0L
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => header = ResponseHeader::decode(r.read_bytes())
      (2, LengthDelim) => kvs.push(KeyValue::decode(r.read_bytes()))
      (3, Varint) => more = r.read_bool()
      (4, Varint) => count = r.read_int64()
      (_, wire) => r.skip(wire)
    }
  }
  { header, kvs, more, count, }
}

///|
/// A write of `value` at `key`, optionally under `lease` (`etcdserverpb.PutRequest`).
#derive(Eq)
pub(all) struct PutRequest {
  key : Bytes
  value : Bytes
  lease : Int64
  prev_kv : Bool
  ignore_value : Bool
  ignore_lease : Bool
}

///|
pub extend PutRequest with Eq::{not_equal, equal}

///|
pub fn PutRequest::empty() -> PutRequest {
  {
    key: b"",
    value: b"",
    lease: 0,
    prev_kv: false,
    ignore_value: false,
    ignore_lease: false,
  }
}

///|
pub fn PutRequest::encode(self : PutRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.key.length() > 0 {
    w.bytes_(1, self.key)
  }
  if self.value.length() > 0 {
    w.bytes_(2, self.value)
  }
  if self.lease != 0 {
    w.int64(3, self.lease)
  }
  if self.prev_kv {
    w.bool_(4, self.prev_kv)
  }
  if self.ignore_value {
    w.bool_(5, self.ignore_value)
  }
  if self.ignore_lease {
    w.bool_(6, self.ignore_lease)
  }
  w.to_bytes()
}

///|
pub fn PutRequest::decode(data : Bytes) -> PutRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = PutRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => req = { ..req, key: r.read_bytes(), }
      (2, LengthDelim) => req = { ..req, value: r.read_bytes(), }
      (3, Varint) => req = { ..req, lease: r.read_int64(), }
      (4, Varint) => req = { ..req, prev_kv: r.read_bool(), }
      (5, Varint) => req = { ..req, ignore_value: r.read_bool(), }
      (6, Varint) => req = { ..req, ignore_lease: r.read_bool(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn PutResponse::empty() -> PutResponse {
  { header: ResponseHeader::empty(), prev_kv: KeyValue::empty(), }
}

///|
/// The previous key/value a `Put` replaced, when `prev_kv` was set
/// (`etcdserverpb.PutResponse`).
#derive(Eq)
pub(all) struct PutResponse {
  header : ResponseHeader
  prev_kv : KeyValue
}

///|
pub extend PutResponse with Eq::{not_equal, equal}

///|
pub fn PutResponse::encode(self : PutResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  if !self.prev_kv.is_empty() {
    w.message_(2, self.prev_kv.encode())
  }
  w.to_bytes()
}

///|
pub fn PutResponse::decode(data : Bytes) -> PutResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut header = ResponseHeader::empty()
  let mut prev_kv = KeyValue::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => header = ResponseHeader::decode(r.read_bytes())
      (2, LengthDelim) => prev_kv = KeyValue::decode(r.read_bytes())
      (_, wire) => r.skip(wire)
    }
  }
  { header, prev_kv, }
}

///|
/// A delete over `[key, range_end)` (`etcdserverpb.DeleteRangeRequest`).
#derive(Eq)
pub(all) struct DeleteRangeRequest {
  key : Bytes
  range_end : Bytes
  prev_kv : Bool
}

///|
pub extend DeleteRangeRequest with Eq::{not_equal, equal}

///|
pub fn DeleteRangeRequest::empty() -> DeleteRangeRequest {
  { key: b"", range_end: b"", prev_kv: false, }
}

///|
pub fn DeleteRangeRequest::encode(self : DeleteRangeRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.key.length() > 0 {
    w.bytes_(1, self.key)
  }
  if self.range_end.length() > 0 {
    w.bytes_(2, self.range_end)
  }
  if self.prev_kv {
    w.bool_(3, self.prev_kv)
  }
  w.to_bytes()
}

///|
pub fn DeleteRangeRequest::decode(
  data : Bytes,
) -> DeleteRangeRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = DeleteRangeRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => req = { ..req, key: r.read_bytes(), }
      (2, LengthDelim) => req = { ..req, range_end: r.read_bytes(), }
      (3, Varint) => req = { ..req, prev_kv: r.read_bool(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn DeleteRangeResponse::empty() -> DeleteRangeResponse {
  { header: ResponseHeader::empty(), deleted: 0, prev_kvs: [], }
}

///|
/// The count removed and, when `prev_kv` was set, the key/values that were
/// (`etcdserverpb.DeleteRangeResponse`).
#derive(Eq)
pub(all) struct DeleteRangeResponse {
  header : ResponseHeader
  deleted : Int64
  prev_kvs : Array[KeyValue]
}

///|
pub extend DeleteRangeResponse with Eq::{not_equal, equal}

///|
pub fn DeleteRangeResponse::encode(self : DeleteRangeResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  if self.deleted != 0 {
    w.int64(2, self.deleted)
  }
  for kv in self.prev_kvs {
    w.message_(3, kv.encode())
  }
  w.to_bytes()
}

///|
pub fn DeleteRangeResponse::decode(
  data : Bytes,
) -> DeleteRangeResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut header = ResponseHeader::empty()
  let mut deleted = 0L
  let prev_kvs : Array[KeyValue] = []
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => header = ResponseHeader::decode(r.read_bytes())
      (2, Varint) => deleted = r.read_int64()
      (3, LengthDelim) => prev_kvs.push(KeyValue::decode(r.read_bytes()))
      (_, wire) => r.skip(wire)
    }
  }
  { header, deleted, prev_kvs, }
}

///|
/// The comparison kind in a `Txn` (`etcdserverpb.Compare.CompareResult`).
#derive(Eq)
pub(all) enum CompareResult {
  Equal = 0
  Greater = 1
  Less = 2
  NotEqual = 3
}

///|
pub extend CompareResult with Eq::{not_equal, equal}

///|
pub fn CompareResult::to_int(self : CompareResult) -> Int32 {
  match self {
    Equal => 0
    Greater => 1
    Less => 2
    NotEqual => 3
  }
}

///|
pub fn CompareResult::from_int(n : Int32) -> CompareResult {
  if n == 1 {
    Greater
  } else if n == 2 {
    Less
  } else if n == 3 {
    NotEqual
  } else {
    Equal
  }
}

///|
/// What a `Txn` compares (`etcdserverpb.Compare.CompareTarget`).
#derive(Eq)
pub(all) enum CompareTarget {
  Version = 0
  Create = 1
  Mod = 2
  Value = 3
  Lease = 4
}

///|
pub extend CompareTarget with Eq::{not_equal, equal}

///|
pub fn CompareTarget::to_int(self : CompareTarget) -> Int32 {
  match self {
    Version => 0
    Create => 1
    Mod => 2
    Value => 3
    Lease => 4
  }
}

///|
pub fn CompareTarget::from_int(n : Int32) -> CompareTarget {
  if n == 1 {
    Create
  } else if n == 2 {
    Mod
  } else if n == 3 {
    Value
  } else if n == 4 {
    Lease
  } else {
    Version
  }
}

///|
/// The value a `Compare` tests, the oneof `target_union` of `etcdserverpb.Compare`.
#derive(Eq)
pub(all) enum CmpTarget {
  Version(Int64)
  CreateRevision(Int64)
  ModRevision(Int64)
  Value(Bytes)
  Lease(Int64)
}

///|
pub extend CmpTarget with Eq::{not_equal, equal}

///|
/// One guarded test in a `Txn` (`etcdserverpb.Compare`): compare `target` of `key`
/// (or `[key, range_end)`) against `target_union` with `result`.
#derive(Eq)
pub(all) struct Compare {
  result : CompareResult
  target : CompareTarget
  key : Bytes
  range_end : Bytes
  target_union : CmpTarget
}

///|
pub extend Compare with Eq::{not_equal, equal}

///|
pub fn Compare::empty() -> Compare {
  {
    result: Equal,
    target: Version,
    key: b"",
    range_end: b"",
    target_union: Version(0),
  }
}

///|
pub fn Compare::encode(self : Compare) -> Bytes {
  let w = @proto.PbWriter::new()
  w.enum_(1, self.result.to_int())
  w.enum_(2, self.target.to_int())
  if self.key.length() > 0 {
    w.bytes_(3, self.key)
  }
  if self.range_end.length() > 0 {
    w.bytes_(64, self.range_end)
  }
  match self.target_union {
    Version(v) => w.int64(4, v)
    CreateRevision(v) => w.int64(5, v)
    ModRevision(v) => w.int64(6, v)
    Value(v) => w.bytes_(7, v)
    Lease(v) => w.int64(8, v)
  }
  w.to_bytes()
}

///|
pub fn Compare::decode(data : Bytes) -> Compare raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut cmp = Compare::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, Varint) =>
        cmp = { ..cmp, result: CompareResult::from_int(r.read_int32()), }
      (2, Varint) =>
        cmp = { ..cmp, target: CompareTarget::from_int(r.read_int32()), }
      (3, LengthDelim) => cmp = { ..cmp, key: r.read_bytes(), }
      (4, Varint) => cmp = { ..cmp, target_union: Version(r.read_int64()), }
      (5, Varint) =>
        cmp = { ..cmp, target_union: CreateRevision(r.read_int64()), }
      (6, Varint) => cmp = { ..cmp, target_union: ModRevision(r.read_int64()), }
      (7, LengthDelim) => cmp = { ..cmp, target_union: Value(r.read_bytes()), }
      (8, Varint) => cmp = { ..cmp, target_union: Lease(r.read_int64()), }
      (64, LengthDelim) => cmp = { ..cmp, range_end: r.read_bytes(), }
      (_, wire) => r.skip(wire)
    }
  }
  cmp
}

///|
/// A step of a `Txn`, the oneof `request_union` of `etcdserverpb.TxnRequest`.
#derive(Eq)
pub(all) enum RequestOp {
  RequestRange(RangeRequest)
  RequestPut(PutRequest)
  RequestDeleteRange(DeleteRangeRequest)
  RequestTxn(TxnRequest)
}

///|
pub extend RequestOp with Eq::{not_equal, equal}

///|
pub fn RequestOp::encode(self : RequestOp) -> Bytes {
  let w = @proto.PbWriter::new()
  match self {
    RequestRange(x) => w.message_(1, x.encode())
    RequestPut(x) => w.message_(2, x.encode())
    RequestDeleteRange(x) => w.message_(3, x.encode())
    RequestTxn(x) => w.message_(4, x.encode())
  }
  w.to_bytes()
}

///|
pub fn RequestOp::decode(data : Bytes) -> RequestOp raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut result : RequestOp = RequestRange(RangeRequest::empty())
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) =>
        result = RequestRange(RangeRequest::decode(r.read_bytes()))
      (2, LengthDelim) =>
        result = RequestPut(PutRequest::decode(r.read_bytes()))
      (3, LengthDelim) =>
        result = RequestDeleteRange(DeleteRangeRequest::decode(r.read_bytes()))
      (4, LengthDelim) =>
        result = RequestTxn(TxnRequest::decode(r.read_bytes()))
      (_, wire) => r.skip(wire)
    }
  }
  result
}

///|
/// The outcome of a `Txn` step, the oneof `response_union` of
/// `etcdserverpb.TxnResponse`.
#derive(Eq)
pub(all) enum ResponseOp {
  ResponseRange(RangeResponse)
  ResponsePut(PutResponse)
  ResponseDeleteRange(DeleteRangeResponse)
  ResponseTxn(TxnResponse)
}

///|
pub extend ResponseOp with Eq::{not_equal, equal}

///|
pub fn ResponseOp::encode(self : ResponseOp) -> Bytes {
  let w = @proto.PbWriter::new()
  match self {
    ResponseRange(x) => w.message_(1, x.encode())
    ResponsePut(x) => w.message_(2, x.encode())
    ResponseDeleteRange(x) => w.message_(3, x.encode())
    ResponseTxn(x) => w.message_(4, x.encode())
  }
  w.to_bytes()
}

///|
pub fn ResponseOp::decode(data : Bytes) -> ResponseOp raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut result : ResponseOp = ResponseRange(RangeResponse::empty())
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) =>
        result = ResponseRange(RangeResponse::decode(r.read_bytes()))
      (2, LengthDelim) =>
        result = ResponsePut(PutResponse::decode(r.read_bytes()))
      (3, LengthDelim) =>
        result = ResponseDeleteRange(
          DeleteRangeResponse::decode(r.read_bytes()),
        )
      (4, LengthDelim) =>
        result = ResponseTxn(TxnResponse::decode(r.read_bytes()))
      (_, wire) => r.skip(wire)
    }
  }
  result
}

///|
/// A conditional batch (`etcdserverpb.TxnRequest`): when every `compare` holds, the
/// `success` ops run; otherwise the `failure` ops run.
#derive(Eq)
pub(all) struct TxnRequest {
  compare : Array[Compare]
  success : Array[RequestOp]
  failure : Array[RequestOp]
}

///|
pub extend TxnRequest with Eq::{not_equal, equal}

///|
pub fn TxnRequest::empty() -> TxnRequest {
  { compare: [], success: [], failure: [], }
}

///|
pub fn TxnRequest::encode(self : TxnRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  for c in self.compare {
    w.message_(1, c.encode())
  }
  for op in self.success {
    w.message_(2, op.encode())
  }
  for op in self.failure {
    w.message_(3, op.encode())
  }
  w.to_bytes()
}

///|
pub fn TxnRequest::decode(data : Bytes) -> TxnRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let compare : Array[Compare] = []
  let success : Array[RequestOp] = []
  let failure : Array[RequestOp] = []
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => compare.push(Compare::decode(r.read_bytes()))
      (2, LengthDelim) => success.push(RequestOp::decode(r.read_bytes()))
      (3, LengthDelim) => failure.push(RequestOp::decode(r.read_bytes()))
      (_, wire) => r.skip(wire)
    }
  }
  { compare, success, failure, }
}

///|
pub fn TxnResponse::empty() -> TxnResponse {
  { header: ResponseHeader::empty(), succeeded: false, responses: [], }
}

///|
/// The result of a `Txn` (`etcdserverpb.TxnResponse`).
#derive(Eq)
pub(all) struct TxnResponse {
  header : ResponseHeader
  succeeded : Bool
  responses : Array[ResponseOp]
}

///|
pub extend TxnResponse with Eq::{not_equal, equal}

///|
pub fn TxnResponse::encode(self : TxnResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  if self.succeeded {
    w.bool_(2, self.succeeded)
  }
  for op in self.responses {
    w.message_(3, op.encode())
  }
  w.to_bytes()
}

///|
pub fn TxnResponse::decode(data : Bytes) -> TxnResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut header = ResponseHeader::empty()
  let mut succeeded = false
  let responses : Array[ResponseOp] = []
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => header = ResponseHeader::decode(r.read_bytes())
      (2, Varint) => succeeded = r.read_bool()
      (3, LengthDelim) => responses.push(ResponseOp::decode(r.read_bytes()))
      (_, wire) => r.skip(wire)
    }
  }
  { header, succeeded, responses, }
}

///|
/// A request to discard history before `revision` (`etcdserverpb.CompactionRequest`).
#derive(Eq)
pub(all) struct CompactionRequest {
  revision : Int64
  physical : Bool
}

///|
pub extend CompactionRequest with Eq::{not_equal, equal}

///|
pub fn CompactionRequest::empty() -> CompactionRequest {
  { revision: 0, physical: false, }
}

///|
pub fn CompactionRequest::encode(self : CompactionRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.revision != 0 {
    w.int64(1, self.revision)
  }
  if self.physical {
    w.bool_(2, self.physical)
  }
  w.to_bytes()
}

///|
pub fn CompactionRequest::decode(
  data : Bytes,
) -> CompactionRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = CompactionRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, Varint) => req = { ..req, revision: r.read_int64(), }
      (2, Varint) => req = { ..req, physical: r.read_bool(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn CompactionResponse::empty() -> CompactionResponse {
  { header: ResponseHeader::empty(), }
}

///|
/// The result of a compaction (`etcdserverpb.CompactionResponse`).
#derive(Eq)
pub(all) struct CompactionResponse {
  header : ResponseHeader
}

///|
pub extend CompactionResponse with Eq::{not_equal, equal}

///|
pub fn CompactionResponse::encode(self : CompactionResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  w.to_bytes()
}

///|
pub fn CompactionResponse::decode(
  data : Bytes,
) -> CompactionResponse raise @proto.PbError {
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
