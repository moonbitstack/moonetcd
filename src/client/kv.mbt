// KV: the plain key-value operations of etcd v3 (etcdserverpb.KV), matching the
// surface of clientv3's `KV` — `Put`, `Range`, `DeleteRange`, `Txn`, `Compact` — plus
// a few `Get*` conveniences built on `Range`.

///|
/// A typed handle for the KV service. Obtain it with `client.kv()`.
pub struct KV {
  client : Client
}

///|
/// Put `key` = `value`; `lease` (when non-zero) attaches the key to a lease. With
/// `prev_kv` set, the previous `KeyValue` comes back in the response's `prev_kv`.
pub async fn KV::put(
  self : KV,
  key : Bytes,
  value : Bytes,
  lease? : Int64,
  prev_kv? : Bool,
) -> PutResponse raise EtcdError {
  let req = @moonetcd.PutRequest::{
    key,
    value,
    lease: lease.unwrap_or(0),
    prev_kv: prev_kv.unwrap_or(false),
    ignore_value: false,
    ignore_lease: false,
  }
  self.client.rpc(
    "/etcdserverpb.KV/Put",
    req.encode(),
    @moonetcd.PutResponse::decode,
  )
}

///|
/// Read a single key.
pub async fn KV::get(self : KV, key : Bytes) -> RangeResponse raise EtcdError {
  self.range(@moonetcd.RangeRequest::{ ..@moonetcd.RangeRequest::empty(), key, })
}

///|
/// Read every key under `prefix` (`[prefix, prefix+1)`), in key order.
pub async fn KV::get_prefix(
  self : KV,
  prefix : Bytes,
) -> RangeResponse raise EtcdError {
  let (start, end) = @moonetcd.prefix_range(prefix)
  self.range(@moonetcd.RangeRequest::{
    ..@moonetcd.RangeRequest::empty(),
    key: start,
    range_end: end,
  })
}

///|
/// Read the keys in `[key, range_end)` (an empty `range_end` is a single key).
pub async fn KV::range(
  self : KV,
  req : RangeRequest,
) -> RangeResponse raise EtcdError {
  self.client.rpc(
    "/etcdserverpb.KV/Range",
    req.encode(),
    @moonetcd.RangeResponse::decode,
  )
}

///|
/// Delete `key` (or the range `[key, range_end)`); with `prev_kv` the deleted values
/// come back in `prev_kvs`.
pub async fn KV::delete_range(
  self : KV,
  req : DeleteRangeRequest,
) -> DeleteRangeResponse raise EtcdError {
  self.client.rpc(
    "/etcdserverpb.KV/DeleteRange",
    req.encode(),
    @moonetcd.DeleteRangeResponse::decode,
  )
}

///|
/// Run a `Txn`: the comparisons decide whether the success or the failure ops run.
pub async fn KV::txn(
  self : KV,
  req : TxnRequest,
) -> TxnResponse raise EtcdError {
  self.client.rpc(
    "/etcdserverpb.KV/Txn",
    req.encode(),
    @moonetcd.TxnResponse::decode,
  )
}

///|
/// Compact the key-value store up to `revision`. `physical` forces a physical compaction.
pub async fn KV::compact(
  self : KV,
  revision : Int64,
  physical? : Bool,
) -> CompactionResponse raise EtcdError {
  let req = @moonetcd.CompactionRequest::{
    revision,
    physical: physical.unwrap_or(true),
  }
  self.client.rpc(
    "/etcdserverpb.KV/Compact",
    req.encode(),
    @moonetcd.CompactionResponse::decode,
  )
}
