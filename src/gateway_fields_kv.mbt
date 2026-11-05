// The messages of etcd's KV, lease, watch and mvcc services, as the HTTP/JSON
// gateway names their fields. One entry per message; `gateway_json.mbt` reads it in
// both directions, and `scripts/check_field_numbers.py` checks it against etcd's
// .proto files.

///|
fn kv_message_fields(name : String) -> Array[JsonField]? {
  match name {
    "ResponseHeader" =>
      Some([
        { number: 1, name: "cluster_id", kind: UInt64, presence: false, },
        { number: 2, name: "member_id", kind: UInt64, presence: false, },
        { number: 3, name: "revision", kind: Int64, presence: false, },
        { number: 4, name: "raft_term", kind: UInt64, presence: false, },
      ])
    "KeyValue" =>
      Some([
        { number: 1, name: "key", kind: Bytes, presence: false, },
        { number: 2, name: "create_revision", kind: Int64, presence: false, },
        { number: 3, name: "mod_revision", kind: Int64, presence: false, },
        { number: 4, name: "version", kind: Int64, presence: false, },
        { number: 5, name: "value", kind: Bytes, presence: false, },
        { number: 6, name: "lease", kind: Int64, presence: false, },
      ])
    "Event" =>
      Some([
        {
          number: 1,
          name: "type",
          kind: Enum(["PUT", "DELETE"]),
          presence: false,
        },
        { number: 2, name: "kv", kind: Message("KeyValue"), presence: false, },
        {
          number: 3,
          name: "prev_kv",
          kind: Message("KeyValue"),
          presence: false,
        },
      ])
    "RangeRequest" =>
      Some([
        { number: 1, name: "key", kind: Bytes, presence: false, },
        { number: 2, name: "range_end", kind: Bytes, presence: false, },
        { number: 3, name: "limit", kind: Int64, presence: false, },
        { number: 4, name: "revision", kind: Int64, presence: false, },
        {
          number: 5,
          name: "sort_order",
          kind: Enum(["NONE", "ASCEND", "DESCEND"]),
          presence: false,
        },
        {
          number: 6,
          name: "sort_target",
          kind: Enum(["KEY", "VERSION", "CREATE", "MOD", "VALUE"]),
          presence: false,
        },
        { number: 7, name: "serializable", kind: Bool, presence: false, },
        { number: 8, name: "keys_only", kind: Bool, presence: false, },
        { number: 9, name: "count_only", kind: Bool, presence: false, },
        { number: 10, name: "min_mod_revision", kind: Int64, presence: false, },
        { number: 11, name: "max_mod_revision", kind: Int64, presence: false, },
        {
          number: 12,
          name: "min_create_revision",
          kind: Int64,
          presence: false,
        },
        {
          number: 13,
          name: "max_create_revision",
          kind: Int64,
          presence: false,
        },
      ])
    "RangeResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
        {
          number: 2,
          name: "kvs",
          kind: Rep(Message("KeyValue")),
          presence: false,
        },
        { number: 3, name: "more", kind: Bool, presence: false, },
        { number: 4, name: "count", kind: Int64, presence: false, },
      ])
    "PutRequest" =>
      Some([
        { number: 1, name: "key", kind: Bytes, presence: false, },
        { number: 2, name: "value", kind: Bytes, presence: false, },
        { number: 3, name: "lease", kind: Int64, presence: false, },
        { number: 4, name: "prev_kv", kind: Bool, presence: false, },
        { number: 5, name: "ignore_value", kind: Bool, presence: false, },
        { number: 6, name: "ignore_lease", kind: Bool, presence: false, },
      ])
    "PutResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
        {
          number: 2,
          name: "prev_kv",
          kind: Message("KeyValue"),
          presence: false,
        },
      ])
    "DeleteRangeRequest" =>
      Some([
        { number: 1, name: "key", kind: Bytes, presence: false, },
        { number: 2, name: "range_end", kind: Bytes, presence: false, },
        { number: 3, name: "prev_kv", kind: Bool, presence: false, },
      ])
    "DeleteRangeResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
        { number: 2, name: "deleted", kind: Int64, presence: false, },
        {
          number: 3,
          name: "prev_kvs",
          kind: Rep(Message("KeyValue")),
          presence: false,
        },
      ])
    "TxnRequest" =>
      Some([
        {
          number: 1,
          name: "compare",
          kind: Rep(Message("Compare")),
          presence: false,
        },
        {
          number: 2,
          name: "success",
          kind: Rep(Message("RequestOp")),
          presence: false,
        },
        {
          number: 3,
          name: "failure",
          kind: Rep(Message("RequestOp")),
          presence: false,
        },
      ])
    "TxnResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
        { number: 2, name: "succeeded", kind: Bool, presence: false, },
        {
          number: 3,
          name: "responses",
          kind: Rep(Message("ResponseOp")),
          presence: false,
        },
      ])
    "Compare" =>
      Some([
        {
          number: 1,
          name: "result",
          kind: Enum(["EQUAL", "GREATER", "LESS", "NOT_EQUAL"]),
          presence: false,
        },
        {
          number: 2,
          name: "target",
          kind: Enum(["VERSION", "CREATE", "MOD", "VALUE", "LEASE"]),
          presence: false,
        },
        { number: 3, name: "key", kind: Bytes, presence: false, },
        { number: 4, name: "version", kind: Int64, presence: true, },
        { number: 5, name: "create_revision", kind: Int64, presence: true, },
        { number: 6, name: "mod_revision", kind: Int64, presence: true, },
        { number: 7, name: "value", kind: Bytes, presence: true, },
        { number: 8, name: "lease", kind: Int64, presence: true, },
        { number: 64, name: "range_end", kind: Bytes, presence: false, },
      ])
    "RequestOp" =>
      Some([
        {
          number: 1,
          name: "request_range",
          kind: Message("RangeRequest"),
          presence: true,
        },
        {
          number: 2,
          name: "request_put",
          kind: Message("PutRequest"),
          presence: true,
        },
        {
          number: 3,
          name: "request_delete_range",
          kind: Message("DeleteRangeRequest"),
          presence: true,
        },
        {
          number: 4,
          name: "request_txn",
          kind: Message("TxnRequest"),
          presence: true,
        },
      ])
    "ResponseOp" =>
      Some([
        {
          number: 1,
          name: "response_range",
          kind: Message("RangeResponse"),
          presence: true,
        },
        {
          number: 2,
          name: "response_put",
          kind: Message("PutResponse"),
          presence: true,
        },
        {
          number: 3,
          name: "response_delete_range",
          kind: Message("DeleteRangeResponse"),
          presence: true,
        },
        {
          number: 4,
          name: "response_txn",
          kind: Message("TxnResponse"),
          presence: true,
        },
      ])
    "CompactionRequest" =>
      Some([
        { number: 1, name: "revision", kind: Int64, presence: false, },
        { number: 2, name: "physical", kind: Bool, presence: false, },
      ])
    "CompactionResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
      ])
    "LeaseGrantRequest" =>
      Some([
        { number: 1, name: "TTL", kind: Int64, presence: false, },
        { number: 2, name: "ID", kind: Int64, presence: false, },
      ])
    "LeaseGrantResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
        { number: 2, name: "ID", kind: Int64, presence: false, },
        { number: 3, name: "TTL", kind: Int64, presence: false, },
        { number: 4, name: "error", kind: Str, presence: false, },
      ])
    "LeaseRevokeRequest" =>
      Some([{ number: 1, name: "ID", kind: Int64, presence: false, }])
    "LeaseRevokeResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
      ])
    "LeaseTimeToLiveRequest" =>
      Some([
        { number: 1, name: "ID", kind: Int64, presence: false, },
        { number: 2, name: "keys", kind: Bool, presence: false, },
      ])
    "LeaseTimeToLiveResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
        { number: 2, name: "ID", kind: Int64, presence: false, },
        { number: 3, name: "TTL", kind: Int64, presence: false, },
        { number: 4, name: "grantedTTL", kind: Int64, presence: false, },
        { number: 5, name: "keys", kind: Rep(Bytes), presence: false, },
      ])
    "LeaseLeasesRequest" => Some([])
    "LeaseLeasesResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
        {
          number: 2,
          name: "leases",
          kind: Rep(Message("LeaseStatus")),
          presence: false,
        },
      ])
    "LeaseStatus" =>
      Some([{ number: 1, name: "ID", kind: Int64, presence: false, }])
    "LeaseKeepAliveRequest" =>
      Some([{ number: 1, name: "ID", kind: Int64, presence: false, }])
    "LeaseKeepAliveResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
        { number: 2, name: "ID", kind: Int64, presence: false, },
        { number: 3, name: "TTL", kind: Int64, presence: false, },
      ])
    "WatchRequest" =>
      Some([
        {
          number: 1,
          name: "create_request",
          kind: Message("WatchCreateRequest"),
          presence: true,
        },
        {
          number: 2,
          name: "cancel_request",
          kind: Message("WatchCancelRequest"),
          presence: true,
        },
        {
          number: 3,
          name: "progress_request",
          kind: Message("WatchProgressRequest"),
          presence: true,
        },
      ])
    "WatchCreateRequest" =>
      Some([
        { number: 1, name: "key", kind: Bytes, presence: false, },
        { number: 2, name: "range_end", kind: Bytes, presence: false, },
        { number: 3, name: "start_revision", kind: Int64, presence: false, },
        { number: 4, name: "progress_notify", kind: Bool, presence: false, },
        {
          number: 5,
          name: "filters",
          kind: Rep(Enum(["NOPUT", "NODELETE"])),
          presence: false,
        },
        { number: 6, name: "prev_kv", kind: Bool, presence: false, },
        { number: 7, name: "watch_id", kind: Int64, presence: false, },
        { number: 8, name: "fragment", kind: Bool, presence: false, },
      ])
    "WatchCancelRequest" =>
      Some([{ number: 1, name: "watch_id", kind: Int64, presence: false, }])
    "WatchProgressRequest" => Some([])
    "WatchResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
        { number: 2, name: "watch_id", kind: Int64, presence: false, },
        { number: 3, name: "created", kind: Bool, presence: false, },
        { number: 4, name: "canceled", kind: Bool, presence: false, },
        { number: 5, name: "compact_revision", kind: Int64, presence: false, },
        { number: 6, name: "cancel_reason", kind: Str, presence: false, },
        { number: 7, name: "fragment", kind: Bool, presence: false, },
        {
          number: 11,
          name: "events",
          kind: Rep(Message("Event")),
          presence: false,
        },
      ])
    _ => None
  }
}
