// Network-free unit tests for the protobuf codecs. Every message type round-trips
// through encode -> decode and comes back equal; the oneof unions (Compare, the two
// *Op, WatchRequest) and the key helpers are covered explicitly. No socket, no etcd.

// ===== Key layout helpers =====

///|
test "key: prefix_range increments the last byte" {
  // "a" -> ["a", "b")
  let (s, e) = prefix_range(b"a")
  assert_eq(s == b"a", true)
  assert_eq(e == b"b", true)
  // "ab" -> ["ab", "ac")
  let (s2, e2) = prefix_range(b"ab")
  assert_eq(s2 == b"ab", true)
  assert_eq(e2 == b"ac", true)
}

///|
test "key: prefix_range drops an overflowing 0xff byte" {
  // "a\xff" -> ["a\xff", "b")
  let (s, e) = prefix_range(b"a\xff")
  assert_eq(s == b"a\xff", true)
  assert_eq(e == b"b", true)
  // all 0xff rolls off to the empty end
  let (s2, e2) = prefix_range(b"\xff\xff")
  assert_eq(s2 == b"\xff\xff", true)
  assert_eq(e2 == b"", true)
}

///|
test "key: prefix / exact / has_prefix" {
  assert_eq(prefix(b"x") == b"y", true)
  let (lo, hi) = exact(b"x")
  assert_eq(lo == b"x", true)
  assert_eq(hi == b"y", true)
  assert_eq(has_prefix(b"abc", b"ab"), true)
  assert_eq(has_prefix(b"ab", b"abc"), false)
  assert_eq(has_prefix(b"abc", b"x"), false)
}

// ===== Enum to/from_int symmetry =====

///|
test "enum: SortOrder to/from_int round-trips" {
  assert_eq(SortOrder::to_int(SortOrder::None), 0)
  assert_eq(SortOrder::to_int(SortOrder::Ascend), 1)
  assert_eq(SortOrder::to_int(SortOrder::Descend), 2)
  assert_eq(SortOrder::from_int(0).to_int(), 0)
  assert_eq(SortOrder::from_int(1).to_int(), 1)
  assert_eq(SortOrder::from_int(2).to_int(), 2)
}

///|
test "enum: CompareResult to/from_int round-trips" {
  assert_eq(CompareResult::from_int(0).to_int(), 0)
  assert_eq(CompareResult::from_int(1).to_int(), 1)
  assert_eq(CompareResult::from_int(2).to_int(), 2)
  assert_eq(CompareResult::from_int(3).to_int(), 3)
  assert_eq(CompareResult::to_int(CompareResult::NotEqual), 3)
}

// ===== mvccpb =====

///|
test "mvccpb: KeyValue round-trips with non-default fields" {
  let kv = {
    key: b"mykey",
    create_revision: 1L,
    mod_revision: 2L,
    version: 3L,
    value: b"myvalue",
    lease: 4L,
  }
  let dec = KeyValue::decode(kv.encode())
  assert_eq(dec.encode(), kv.encode())
}

///|
test "mvccpb: KeyValue empty() round-trips" {
  let kv = KeyValue::empty()
  assert_eq(KeyValue::decode(kv.encode()).encode(), kv.encode())
  assert_eq(kv.is_empty(), true)
}

///|
test "mvccpb: Event round-trips (Put and Delete, with prev_kv)" {
  let kv = {
    key: b"k",
    mod_revision: 7L,
    value: b"v",
    version: 2L,
    create_revision: 1L,
    lease: 0L,
  }
  let prev = {
    key: b"k",
    mod_revision: 6L,
    value: b"old",
    version: 1L,
    create_revision: 1L,
    lease: 0L,
  }
  let put = { event_type: Put, kv, prev_kv: prev, }
  assert_eq(Event::decode(put.encode()).encode(), put.encode())
  let del = { event_type: Delete, kv, prev_kv: KeyValue::empty(), }
  assert_eq(Event::decode(del.encode()).encode(), del.encode())
  // default (Put) must be omitted and still round-trip
  let def = { event_type: Put, kv, prev_kv: KeyValue::empty(), }
  assert_eq(Event::decode(def.encode()).encode(), def.encode())
}

// ===== KV service =====

///|
test "kv: ResponseHeader round-trips" {
  let h = { cluster_id: 1UL, member_id: 2UL, revision: 3L, raft_term: 4UL, }
  assert_eq(ResponseHeader::decode(h.encode()).encode(), h.encode())
}

///|
test "kv: RangeRequest round-trips" {
  let r : RangeRequest = {
    key: b"abc",
    range_end: b"abd",
    limit: 10L,
    revision: 7L,
    sort_order: Ascend,
    sort_target: Version,
    serializable: true,
    keys_only: true,
    count_only: true,
    min_mod_revision: 1L,
    max_mod_revision: 2L,
    min_create_revision: 3L,
    max_create_revision: 4L,
  }
  assert_eq(RangeRequest::decode(r.encode()).encode(), r.encode())
}

///|
test "kv: RangeResponse round-trips" {
  let kv = {
    key: b"k",
    mod_revision: 1L,
    value: b"v",
    version: 1L,
    create_revision: 1L,
    lease: 0L,
  }
  let r = {
    header: { cluster_id: 9UL, member_id: 8UL, revision: 5L, raft_term: 4UL, },
    kvs: [kv],
    more: true,
    count: 1L,
  }
  assert_eq(RangeResponse::decode(r.encode()).encode(), r.encode())
}

///|
test "kv: PutRequest / PutResponse round-trip" {
  let req = {
    key: b"k",
    value: b"v",
    lease: 9L,
    prev_kv: true,
    ignore_value: true,
    ignore_lease: true,
  }
  assert_eq(PutRequest::decode(req.encode()).encode(), req.encode())
  let resp = { header: ResponseHeader::empty(), prev_kv: KeyValue::empty(), }
  assert_eq(PutResponse::decode(resp.encode()).encode(), resp.encode())
}

///|
test "kv: DeleteRangeRequest / DeleteRangeResponse round-trip" {
  let req = { key: b"k", range_end: b"r", prev_kv: true, }
  assert_eq(DeleteRangeRequest::decode(req.encode()).encode(), req.encode())
  let resp = {
    header: ResponseHeader::empty(),
    deleted: 3L,
    prev_kvs: [KeyValue::empty()],
  }
  assert_eq(DeleteRangeResponse::decode(resp.encode()).encode(), resp.encode())
}

///|
test "kv: Compare round-trips for every target_union variant" {
  let base = {
    ..Compare::empty(),
    result: Greater,
    target: Version,
    key: b"k",
  }
  let variants : Array[CmpTarget] = [
    Version(7L),
    CreateRevision(7L),
    ModRevision(7L),
    Value(b"x"),
    Lease(7L),
  ]
  for tu in variants {
    let c = { ..base, target_union: tu, }
    assert_eq(Compare::decode(c.encode()).encode(), c.encode())
  }
}

///|
test "kv: RequestOp / ResponseOp round-trip every variant" {
  let rr = { ..RangeRequest::empty(), key: b"r", }
  let pr = {
    key: b"k",
    value: b"v",
    lease: 0L,
    prev_kv: false,
    ignore_value: false,
    ignore_lease: false,
  }
  let dr = { key: b"k", range_end: b"", prev_kv: false, }
  let txn = { compare: [], success: [], failure: [], }
  let req_ops : Array[RequestOp] = [
    RequestRange(rr),
    RequestPut(pr),
    RequestDeleteRange(dr),
    RequestTxn(txn),
  ]
  for op in req_ops {
    assert_eq(RequestOp::decode(op.encode()).encode(), op.encode())
  }
  let rresp = {
    header: ResponseHeader::empty(),
    kvs: [],
    more: false,
    count: 0L,
  }
  let presp = { header: ResponseHeader::empty(), prev_kv: KeyValue::empty(), }
  let dresp = { header: ResponseHeader::empty(), deleted: 0L, prev_kvs: [], }
  let tresp = {
    header: ResponseHeader::empty(),
    succeeded: false,
    responses: [],
  }
  let resp_ops : Array[ResponseOp] = [
    ResponseRange(rresp),
    ResponsePut(presp),
    ResponseDeleteRange(dresp),
    ResponseTxn(tresp),
  ]
  for op in resp_ops {
    assert_eq(ResponseOp::decode(op.encode()).encode(), op.encode())
  }
}

///|
test "kv: TxnRequest / TxnResponse round-trip" {
  let cmp = {
    ..Compare::empty(),
    result: Equal,
    target: Version,
    key: b"k",
    target_union: Version(1L),
  }
  let op = RequestRange({ ..RangeRequest::empty(), key: b"r", })
  let req = { compare: [cmp], success: [op], failure: [], }
  assert_eq(TxnRequest::decode(req.encode()).encode(), req.encode())
  let resp = {
    header: ResponseHeader::empty(),
    succeeded: true,
    responses: [
      ResponseRange({
        header: ResponseHeader::empty(),
        kvs: [],
        more: false,
        count: 0L,
      }),
    ],
  }
  assert_eq(TxnResponse::decode(resp.encode()).encode(), resp.encode())
}

///|
test "kv: CompactionRequest / CompactionResponse round-trip" {
  let req = { revision: 5L, physical: true, }
  assert_eq(CompactionRequest::decode(req.encode()).encode(), req.encode())
  let resp : CompactionResponse = { header: ResponseHeader::empty(), }
  assert_eq(CompactionResponse::decode(resp.encode()).encode(), resp.encode())
}

// ===== Watch service =====

///|
test "watch: WatchCreateRequest round-trips" {
  let r : WatchCreateRequest = {
    key: b"k",
    range_end: b"r",
    start_revision: 5L,
    progress_notify: true,
    filters: [NoPut, NoDelete],
    prev_kv: true,
    watch_id: 7L,
    fragment: true,
  }
  assert_eq(WatchCreateRequest::decode(r.encode()).encode(), r.encode())
}

///|
test "watch: WatchCancelRequest / WatchProgressRequest round-trip" {
  let cancel = { watch_id: 3L, }
  assert_eq(
    WatchCancelRequest::decode(cancel.encode()).encode(),
    cancel.encode(),
  )
  let progress = WatchProgressRequest::{ }
  assert_eq(
    WatchProgressRequest::decode(progress.encode()).encode(),
    progress.encode(),
  )
}

///|
test "watch: WatchRequest oneof round-trips every variant" {
  let create = CreateRequest({
    ..WatchCreateRequest::empty(),
    key: b"k",
    watch_id: 1L,
  })
  assert_eq(WatchRequest::decode(create.encode()).encode(), create.encode())
  let cancel = CancelRequest({ watch_id: 2L, })
  assert_eq(WatchRequest::decode(cancel.encode()).encode(), cancel.encode())
  let progress = ProgressRequest(WatchProgressRequest::{ })
  assert_eq(WatchRequest::decode(progress.encode()).encode(), progress.encode())
}

///|
test "watch: WatchResponse round-trips" {
  let ev = {
    event_type: Delete,
    kv: {
      key: b"k",
      mod_revision: 1L,
      value: b"v",
      version: 1L,
      create_revision: 1L,
      lease: 0L,
    },
    prev_kv: KeyValue::empty(),
  }
  let r = {
    ..WatchResponse::empty(),
    watch_id: 2L,
    created: true,
    canceled: true,
    events: [ev],
    compact_revision: 3L,
    cancel_reason: "because",
    fragment: true,
  }
  assert_eq(WatchResponse::decode(r.encode()).encode(), r.encode())
}

// ===== Lease service =====

///|
test "lease: LeaseGrant round-trips" {
  let req = { ttl: 10L, id: 5L, }
  assert_eq(LeaseGrantRequest::decode(req.encode()).encode(), req.encode())
  let resp = {
    header: ResponseHeader::empty(),
    id: 5L,
    ttl: 10L,
    error: "boom",
  }
  assert_eq(LeaseGrantResponse::decode(resp.encode()).encode(), resp.encode())
}

///|
test "lease: LeaseRevoke / KeepAlive / TimeToLive round-trip" {
  let revoke : LeaseRevokeRequest = { id: 5L, }
  assert_eq(
    LeaseRevokeRequest::decode(revoke.encode()).encode(),
    revoke.encode(),
  )
  let revoke_resp : LeaseRevokeResponse = { header: ResponseHeader::empty(), }
  assert_eq(
    LeaseRevokeResponse::decode(revoke_resp.encode()).encode(),
    revoke_resp.encode(),
  )
  let ka : LeaseKeepAliveRequest = { id: 5L, }
  assert_eq(LeaseKeepAliveRequest::decode(ka.encode()).encode(), ka.encode())
  let ka_resp = { header: ResponseHeader::empty(), id: 5L, ttl: 10L, }
  assert_eq(
    LeaseKeepAliveResponse::decode(ka_resp.encode()).encode(),
    ka_resp.encode(),
  )
  let ttl = { id: 5L, keys: true, }
  assert_eq(LeaseTimeToLiveRequest::decode(ttl.encode()).encode(), ttl.encode())
  let ttl_resp = {
    header: ResponseHeader::empty(),
    id: 5L,
    ttl: 10L,
    granted_ttl: 20L,
    keys: [b"a", b"b"],
  }
  assert_eq(
    LeaseTimeToLiveResponse::decode(ttl_resp.encode()).encode(),
    ttl_resp.encode(),
  )
}

///|
test "lease: LeaseStatus / LeaseLeasesResponse round-trip" {
  let s : LeaseStatus = { id: 5L, }
  assert_eq(LeaseStatus::decode(s.encode()).encode(), s.encode())
  let list = {
    header: ResponseHeader::empty(),
    leases: [{ id: 1L, }, { id: 2L, }],
  }
  assert_eq(LeaseLeasesResponse::decode(list.encode()).encode(), list.encode())
}

// ===== Cluster service =====

///|
test "cluster: Member round-trips" {
  let m = {
    id: 1UL,
    name: "node1",
    peer_urls: ["http://p"],
    client_urls: ["http://c"],
  }
  assert_eq(Member::decode(m.encode()).encode(), m.encode())
}

///|
test "cluster: MemberAddRequest / MemberAddResponse round-trip" {
  let req = { peer_urls: ["http://p"], is_learner: true, }
  assert_eq(MemberAddRequest::decode(req.encode()).encode(), req.encode())
  let m = Member::empty()
  let resp = { header: ResponseHeader::empty(), member_: m, members: [m], }
  assert_eq(MemberAddResponse::decode(resp.encode()).encode(), resp.encode())
}

// ===== Auth service =====

///|
test "auth: Permission round-trips" {
  let p = { key: b"k", range_end: b"r", perm_type: ReadWrite, }
  assert_eq(Permission::decode(p.encode()).encode(), p.encode())
}

///|
test "auth: AuthEnableResponse round-trips" {
  let r : AuthEnableResponse = { header: ResponseHeader::empty(), }
  assert_eq(AuthEnableResponse::decode(r.encode()).encode(), r.encode())
}

///|
test "auth: AuthenticateRequest round-trips" {
  let r : AuthenticateRequest = { name: "u", password: "p", }
  assert_eq(AuthenticateRequest::decode(r.encode()).encode(), r.encode())
}

// ===== Lock service =====

///|
test "lock: LockRequest / LockResponse round-trip" {
  let req = { name: b"mylock", lease: 5L, }
  assert_eq(LockRequest::decode(req.encode()).encode(), req.encode())
  let resp = { header: ResponseHeader::empty(), key: b"lockkey", }
  assert_eq(LockResponse::decode(resp.encode()).encode(), resp.encode())
}

///|
test "lock: UnlockRequest / UnlockResponse round-trip" {
  let req = { key: b"lockkey", }
  assert_eq(UnlockRequest::decode(req.encode()).encode(), req.encode())
  let resp : UnlockResponse = { header: ResponseHeader::empty(), }
  assert_eq(UnlockResponse::decode(resp.encode()).encode(), resp.encode())
}

// ===== Election service =====

///|
test "election: LeaderKey / CampaignRequest round-trip" {
  let k = { name: b"elec", key: b"k", rev: 3L, lease: 5L, }
  assert_eq(LeaderKey::decode(k.encode()).encode(), k.encode())
  let c = { name: b"elec", value: b"v", lease: 5L, }
  assert_eq(CampaignRequest::decode(c.encode()).encode(), c.encode())
}

// ===== Error model =====

///|
test "error: Status and EtcdError messages render" {
  let s = { code: 14, message: "unavailable", }
  assert_eq(s.to_string(), "rpc error: code = 14 desc = unavailable")
  let compacted = Compacted(7L)
  assert_eq(
    compacted.message(),
    "etcdserver: mvcc: required revision has been compacted: 7",
  )
  let future = FutureRev(9L)
  assert_eq(
    future.message(),
    "etcdserver: mvcc: required revision is a future revision: 9",
  )
}

// ===== Wire compatibility with the etcd proto =====

///|
test "kv: Compare encodes etcd's real field numbers" {
  // etcd's Compare puts the scalar oneof at 4..8 (version, create_revision,
  // mod_revision, value, lease) and range_end at 64. A round trip alone would not
  // catch a wrong field number, so pin the exact bytes here.
  let c : Compare = {
    result: Equal,
    target: Value,
    key: b"k",
    range_end: b"z",
    target_union: CmpTarget::Value(b"v"),
  }
  let expected : Bytes = b"\x08\x00\x10\x03\x1a\x01\x6b\x82\x04\x01\x7a\x3a\x01\x76"
  assert_eq(c.encode(), expected)
}

///|
test "watch: a progress notification is a header and nothing else" {
  assert_true(WatchResponse::empty().is_progress_notify())
  assert_false(
    { ..WatchResponse::empty(), created: true, }.is_progress_notify(),
  )
  assert_false(
    { ..WatchResponse::empty(), canceled: true, }.is_progress_notify(),
  )
  assert_false(
    { ..WatchResponse::empty(), compact_revision: 3, }.is_progress_notify(),
  )
}
