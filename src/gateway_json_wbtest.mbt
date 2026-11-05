// The gateway's JSON mapping, tested on its own: the two directions around one
// message, the replies etcd really sent (captured as text, so a mistake in our own
// encoder cannot hide itself), and the places where a wrong reading would look
// right — base64 keys, 64-bit lease ids, and the arms of a oneof.

///|
fn parsed(text : String) -> Json raise {
  @json.parse(text)
}

///|
/// The member `name` of an object, or `None`.
fn field_json(json : Json, name : String) -> Json? {
  match json {
    Object(members) => members.get(name)
    _ => None
  }
}

///|
test "gateway: a put request names its fields the way the .proto does" {
  let req = PutRequest::{
    ..PutRequest::empty(),
    key: b"/moon/one",
    value: b"value",
    lease: 42L,
    prev_kv: true,
  }
  let json = message_json("PutRequest", req.encode())
  // a key is `bytes` on the wire, so the gateway carries it as base64
  assert_eq(field_json(json, "key"), Some(Json::string("L21vb24vb25l")))
  assert_eq(field_json(json, "value"), Some(Json::string("dmFsdWU=")))
  assert_eq(field_json(json, "lease"), Some(Json::string("42")))
  assert_eq(field_json(json, "prev_kv"), Some(Json::boolean(true)))
}

///|
test "gateway: a reply etcd sent reads as the message it names" {
  let text =
    #|{"header":{"cluster_id":"14841639068965178418","member_id":"10276657743932975437","revision":"2","raft_term":"2"},"kvs":[{"key":"cHJvYmUta2V5","create_revision":"2","mod_revision":"2","version":"1","value":"cHJvYmUtdmFsdWU="}],"count":"1"}
  let call = gateway_call("/etcdserverpb.KV/Range").unwrap()
  let resp = RangeResponse::decode(call.decode_reply(text)) catch {
    _ => abort("the reply does not decode")
  }
  assert_eq(resp.kvs.length(), 1)
  assert_eq(resp.kvs[0].key, b"probe-key")
  assert_eq(resp.kvs[0].value, b"probe-value")
  assert_eq(resp.kvs[0].mod_revision, 2L)
  assert_eq(resp.count, 1L)
  assert_eq(resp.header.revision, 2L)
  assert_eq(resp.header.cluster_id, 14841639068965178418UL)
}

///|
test "gateway: a streamed reply is unwrapped, and its events keep their kv" {
  let text =
    #|{"result":{"header":{"cluster_id":"14841639068965178418","member_id":"10276657743932975437","revision":"3","raft_term":"2"},"events":[{"kv":{"key":"cHJvYmUtd2F0Y2g=","create_revision":"3","mod_revision":"3","version":"1","value":"eA=="}}]}}
  let call = gateway_call("/etcdserverpb.Watch/Watch").unwrap()
  let resp = WatchResponse::decode(call.decode_reply(text)) catch {
    _ => abort("the frame does not decode")
  }
  assert_eq(resp.events.length(), 1)
  assert_eq(resp.events[0].kv.key, b"probe-watch")
  assert_eq(resp.events[0].kv.value, b"x")
  assert_true(resp.events[0].event_type == EventType::Put)
  assert_eq(resp.created, false)
}

///|
test "gateway: a status reply carries its sizes as strings" {
  let text =
    #|{"header":{"cluster_id":"14841639068965178418","member_id":"10276657743932975437","revision":"3","raft_term":"2"},"version":"3.5.16","dbSize":"24576","leader":"10276657743932975437","raftIndex":"7","raftTerm":"2","raftAppliedIndex":"7","dbSizeInUse":"16384"}
  let call = gateway_call("/etcdserverpb.Maintenance/Status").unwrap()
  let resp = StatusResponse::decode(call.decode_reply(text)) catch {
    _ => abort("the reply does not decode")
  }
  assert_eq(resp.version, "3.5.16")
  assert_eq(resp.db_size, 24576L)
  assert_eq(resp.leader, 10276657743932975437UL)
  assert_eq(resp.raft_index, 7UL)
}

///|
test "gateway: a txn reply keeps the arm each response took" {
  let text =
    #|{"header":{"revision":"6"},"succeeded":true,"responses":[{"response_put":{"header":{"revision":"6"}}}]}
  let call = gateway_call("/etcdserverpb.KV/Txn").unwrap()
  let resp = TxnResponse::decode(call.decode_reply(text)) catch {
    _ => abort("the reply does not decode")
  }
  assert_eq(resp.succeeded, true)
  assert_eq(resp.responses.length(), 1)
  match resp.responses[0] {
    ResponsePut(_) => ()
    _ => abort("the arm is not a put")
  }
}

///|
test "gateway: a lease id larger than 2^53 survives both directions" {
  let big = 8123456789012345678L
  let json = message_json(
    "LeaseGrantResponse",
    LeaseGrantResponse::{ ..LeaseGrantResponse::empty(), id: big, ttl: 30L, }.encode(),
  )
  assert_eq(field_json(json, "ID"), Some(Json::string("8123456789012345678")))
  let wire = message_wire("LeaseGrantResponse", json)
  let back = LeaseGrantResponse::decode(wire) catch {
    _ => abort("the reply does not decode")
  }
  assert_eq(back.id, big)
}

///|
test "gateway: an enumeration reads by name and writes by number" {
  let text =
    #|{"key":"YQ==","target":"VALUE","result":"EQUAL","value":"Yg=="}
  let wire = message_wire("Compare", parsed(text))
  let back = Compare::decode(wire) catch {
    _ => abort("the compare does not decode")
  }
  assert_eq(back.target.to_int(), 3)
  assert_eq(back.result.to_int(), 0)
  match back.target_union {
    Value(bytes) => assert_eq(bytes, b"b")
    _ => abort("the arm is not a value")
  }
  // and the number etcd also accepts
  let numbers =
    #|{"key":"YQ==","target":3,"result":2}
  let numbered = message_wire("Compare", parsed(numbers))
  let numeric = Compare::decode(numbered) catch {
    _ => abort("the compare does not decode")
  }
  assert_eq(numeric.target.to_int(), 3)
  assert_eq(numeric.result.to_int(), 2)
}

///|
test "gateway: a oneof arm holding the default is still written" {
  let cancel =
    #|{"cancel_request":{"watch_id":"0"}}
  let wire = message_wire("WatchRequest", parsed(cancel))
  let req = WatchRequest::decode(wire) catch {
    _ => abort("the watch request does not decode")
  }
  match req {
    CancelRequest(_) => ()
    _ => abort("the arm is not a cancel")
  }
}

///|
test "gateway: an error envelope becomes the error etcd meant" {
  let text =
    #|{"error":"etcdserver: mvcc: required revision has been compacted","code":11,"message":"etcdserver: mvcc: required revision has been compacted: 5"}
  match gateway_failure(text) {
    Compacted(rev) => assert_eq(rev, 5L)
    other => abort("not a compaction error: " + other.message())
  }
  let refusal =
    #|{"error":"not a token","code":16,"message":"etcdserver: invalid auth token"}
  match gateway_failure(refusal) {
    Refused(status) => {
      assert_eq(status.code, 16)
      assert_eq(status.message, "etcdserver: invalid auth token")
    }
    _ => abort("not a refusal")
  }
}

///|
test "gateway: a broken body is refused rather than guessed" {
  let call = gateway_call("/etcdserverpb.KV/Put").unwrap()
  let code = try {
    let _ = call.decode_reply("not json")
    -1
  } catch {
    EtcdError::Refused(status) => status.code
    _ => -2
  }
  assert_eq(code, 13)
  let bad_base64 =
    #|{"key":"not base64!"}
  let code = try {
    let _ = message_wire("PutRequest", parsed(bad_base64))
    -1
  } catch {
    EtcdError::Refused(status) => status.code
    _ => -2
  }
  assert_eq(code, 3)
  let too_large =
    #|{"lease":"99999999999999999999"}
  let code = try {
    let _ = message_wire("PutRequest", parsed(too_large))
    -1
  } catch {
    EtcdError::Refused(status) => status.code
    _ => -2
  }
  assert_eq(code, 3)
}

///|
test "gateway: every published call names messages the table knows" {
  for
    grpc_method in [
      "/etcdserverpb.KV/Range", "/etcdserverpb.KV/Put", "/etcdserverpb.KV/DeleteRange",
      "/etcdserverpb.KV/Txn", "/etcdserverpb.KV/Compact", "/etcdserverpb.Lease/LeaseGrant",
      "/etcdserverpb.Lease/LeaseRevoke", "/etcdserverpb.Lease/LeaseTimeToLive", "/etcdserverpb.Lease/LeaseLeases",
      "/etcdserverpb.Lease/LeaseKeepAlive", "/etcdserverpb.Watch/Watch", "/etcdserverpb.Cluster/MemberAdd",
      "/etcdserverpb.Cluster/MemberRemove", "/etcdserverpb.Cluster/MemberUpdate",
      "/etcdserverpb.Cluster/MemberList", "/etcdserverpb.Cluster/MemberPromote",
      "/etcdserverpb.Maintenance/Alarm", "/etcdserverpb.Maintenance/Status", "/etcdserverpb.Maintenance/Defragment",
      "/etcdserverpb.Maintenance/Hash", "/etcdserverpb.Maintenance/HashKV", "/etcdserverpb.Maintenance/Snapshot",
      "/etcdserverpb.Maintenance/MoveLeader", "/etcdserverpb.Maintenance/Downgrade",
      "/etcdserverpb.Auth/AuthEnable", "/etcdserverpb.Auth/AuthDisable", "/etcdserverpb.Auth/AuthStatus",
      "/etcdserverpb.Auth/Authenticate", "/etcdserverpb.Auth/UserAdd", "/etcdserverpb.Auth/UserGet",
      "/etcdserverpb.Auth/UserList", "/etcdserverpb.Auth/UserDelete", "/etcdserverpb.Auth/UserChangePassword",
      "/etcdserverpb.Auth/UserGrantRole", "/etcdserverpb.Auth/UserRevokeRole", "/etcdserverpb.Auth/RoleAdd",
      "/etcdserverpb.Auth/RoleGet", "/etcdserverpb.Auth/RoleList", "/etcdserverpb.Auth/RoleDelete",
      "/etcdserverpb.Auth/RoleGrantPermission", "/etcdserverpb.Auth/RoleRevokePermission",
      "/v3lockpb.Lock/Lock", "/v3lockpb.Lock/Unlock", "/v3electionpb.Election/Campaign",
      "/v3electionpb.Election/Proclaim", "/v3electionpb.Election/Leader", "/v3electionpb.Election/Observe",
      "/v3electionpb.Election/Resign",
    ] {
    let call = match gateway_call(grpc_method) {
      Some(call) => call
      None => abort("no gateway path for " + grpc_method)
    }
    // An empty body is the encoding of the empty message, which every request can
    // start from: framing it proves both message names are in the table.
    let _ = call.encode_request(b"") catch {
      _ => abort("request of " + grpc_method + " does not frame")
    }
  }
  assert_true(gateway_call("/etcdserverpb.KV/NoSuchCall") is None)
}
