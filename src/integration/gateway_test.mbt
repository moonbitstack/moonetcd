// The HTTP/JSON gateway as the second transport. One set of cases runs over gRPC and
// again over the gateway, and every case's answer has to come back the same; the
// cases that are only interesting over the gateway — a streamed watch, a lease id
// wider than a JSON number, a token in the `Authorization` header — follow on their
// own.
//
// Without a member these return; with `MOONETCD_LIVE` set, as in CI, a missing server
// fails them.

///|
async fn gateway_connect() -> @client.Client? {
  let client = @client.Client::connect_gateway(live_config())
  let up = try {
    let _ = client.maintenance().status()
    true
  } catch {
    _ => false
  }
  if up {
    Some(client)
  } else {
    client.close()
    if live_required() {
      fail(live_missing())
    }
    None
  }
}

///|
/// `prefix` followed by `suffix`, as the key the gateway will base64 for the wire.
fn key_of(prefix : Bytes, suffix : String) -> Bytes {
  let buffer = @buffer.Buffer()
  buffer.write_bytes(prefix)
  buffer.write_bytes(@utf8.encode(suffix))
  buffer.to_bytes()
}

///|
/// Delete every key under `prefix`.
async fn clear_prefix(client : @client.Client, prefix : Bytes) -> Unit {
  let _ = client
    .kv()
    .delete_range(@moonetcd.DeleteRangeRequest::{
      ..@moonetcd.DeleteRangeRequest::empty(),
      key: prefix,
      range_end: @moonetcd.prefix(prefix),
    })
}

///|
/// Watch one key, put a value to it, and return the value the watch reported. The
/// create is acknowledged before the put, so the event cannot race the registration.
async fn first_event(
  client : @client.Client,
  watched : Bytes,
  value : Bytes,
) -> String {
  let seen : Array[String] = []
  @async.with_task_group <| g => {
    let chan = client
      .watch()
      .watch_create(g, @moonetcd.WatchCreateRequest::{
        ..@moonetcd.WatchCreateRequest::empty(),
        key: watched,
      })
    let _ = chan.next()
    let _ = client.kv().put(watched, value)
    let mut reads = 0
    while reads < 5 && seen.length() == 0 {
      match chan.next() {
        Some(response) =>
          if response.events.length() > 0 {
            seen.push(@utf8.decode_lossy(response.events[0].kv.value[:]))
          } else {
            reads = reads + 1
          }
        None => reads = 5
      }
    }
    chan.cancel()
  }
  match seen {
    [only, ..] => only
    _ => ""
  }
}

///|
/// `unit` repeated `times`, for a value larger than one socket read.
fn chunk(unit : String, times : Int32) -> String {
  let buffer = @buffer.Buffer()
  let piece = @utf8.encode(unit)
  for i = 0; i < times; i = i + 1 {
    buffer.write_bytes(piece)
  }
  @utf8.decode_lossy(buffer.to_bytes()[:])
}

///|
/// The cases both transports must answer alike. Each line records what the server
/// said, of nothing that a later run may legitimately change: revisions and lease ids
/// move, content does not.
async fn same_cases(client : @client.Client, prefix : Bytes) -> Array[String] {
  let out : Array[String] = []
  let kv = client.kv()
  clear_prefix(client, prefix)
  let one = key_of(prefix, "/one")
  let two = key_of(prefix, "/two")
  let _ = kv.put(one, b"alpha")
  let got = kv.get(one)
  let read = match got.kvs {
    [entry] => @utf8.decode_lossy(entry.value[:])
    _ => "-"
  }
  out.push("get: " + got.kvs.length().to_string() + " " + read)
  let _ = kv.put(two, b"beta")
  let under_prefix = kv.get_prefix(prefix)
  out.push("prefix: " + under_prefix.kvs.length().to_string())
  out.push("count: " + (if under_prefix.count >= 2L { "many" } else { "few" }))
  let deleted = kv.delete_range(@moonetcd.DeleteRangeRequest::{
    ..@moonetcd.DeleteRangeRequest::empty(),
    key: prefix,
    range_end: @moonetcd.prefix(prefix),
  })
  out.push("deleted: " + deleted.deleted.to_string())
  // A compared write takes the success arm only when the value is what it was.
  let _ = kv.put(one, b"1")
  let compare = @moonetcd.Compare::{
    ..@moonetcd.Compare::empty(),
    key: one,
    target: @moonetcd.CompareTarget::Value,
    result: @moonetcd.CompareResult::Equal,
    target_union: @moonetcd.CmpTarget::Value(b"1"),
  }
  let transaction = kv.txn(@moonetcd.TxnRequest::{
    compare: [compare],
    success: [
      @moonetcd.RequestOp::RequestPut(@moonetcd.PutRequest::{
        ..@moonetcd.PutRequest::empty(),
        key: one,
        value: b"2",
      }),
    ],
    failure: [
      @moonetcd.RequestOp::RequestPut(@moonetcd.PutRequest::{
        ..@moonetcd.PutRequest::empty(),
        key: one,
        value: b"99",
      }),
    ],
  })
  out.push("txn: " + (if transaction.succeeded { "yes" } else { "no" }))
  out.push("txn value: " + @utf8.decode_lossy(kv.get(one).kvs[0].value[:]))
  // Keys and values are opaque bytes, so the base64 round trip is part of the case.
  let raw = b"\x00\x01\xfe\xff"
  let _ = kv.put(key_of(prefix, "/raw"), raw)
  let raw_back = kv.get(key_of(prefix, "/raw"))
  out.push(
    "raw: " + (if raw_back.kvs[0].value == raw { "same" } else { "changed" }),
  )
  clear_prefix(client, prefix)
  // A lease holds a key until it is revoked, and reports the keys it holds.
  let granted = client.lease().grant(30L)
  out.push("grant: " + (if granted.ttl >= 1L { "ttl" } else { "none" }))
  let _ = kv.put(key_of(prefix, "/leased"), b"x", lease=granted.id)
  let ttl = client.lease().time_to_live(granted.id, keys=true)
  out.push("lease keys: " + ttl.keys.length().to_string())
  out.push(
    "granted ttl: " + (if ttl.granted_ttl >= 1L { "ttl" } else { "none" }),
  )
  let _ = client.lease().revoke(granted.id)
  out.push(
    "after revoke: " +
    kv.get(key_of(prefix, "/leased")).kvs.length().to_string(),
  )
  // A watch reports the put that follows its create.
  out.push(
    "watch: " + first_event(client, key_of(prefix, "/watched"), b"event"),
  )
  clear_prefix(client, prefix)
  // The admin surfaces answer with the same shape.
  let members = client.cluster().member_list().members.length()
  out.push("members: " + (if members >= 1 { "some" } else { "none" }))
  let status = client.maintenance().status()
  out.push(
    "version: " + (if status.version == "" { "unknown" } else { "known" }),
  )
  let alarms = client
    .maintenance()
    .alarm(@moonetcd.AlarmAction::Get, 0UL, @moonetcd.AlarmType::None)
  out.push("alarms: " + alarms.alarms.length().to_string())
  let auth = client.auth().status()
  out.push("auth: " + (if auth.enabled { "on" } else { "off" }))
  out
}

///|
async test "gateway: the same cases answer the same on both transports" {
  match (try_connect(), gateway_connect()) {
    (Some(grpc), Some(gateway)) => {
      let over_grpc = same_cases(grpc, b"/moonetcd-gw/grpc")
      let over_gateway = same_cases(gateway, b"/moonetcd-gw/gateway")
      assert_eq(over_gateway.length(), over_grpc.length())
      for i = 0; i < over_grpc.length(); i = i + 1 {
        assert_eq(over_gateway[i], over_grpc[i])
      }
      grpc.close()
      gateway.close()
    }
    _ => ()
  }
}

///|
async test "gateway: a watch delivers events while the stream is still open" {
  match gateway_connect() {
    None => ()
    Some(client) => {
      let watched = b"/moonetcd-gw/stream"
      let first = first_event(client, watched, b"first")
      assert_eq(first, "first")
      let second = first_event(client, watched, b"second")
      assert_eq(second, "second")
      // A value larger than one read has to be put back together from the pieces the
      // socket hands over; a stream read as if it arrived in one piece loses the head.
      let big = chunk("0123456789abcdef", 3000)
      let reported = first_event(client, watched, @utf8.encode(big))
      assert_eq(reported.length(), big.length())
      let _ = client
        .kv()
        .delete_range(@moonetcd.DeleteRangeRequest::{
          ..@moonetcd.DeleteRangeRequest::empty(),
          key: watched,
        })
      client.close()
    }
  }
}

///|
async test "gateway: a lease id wider than a JSON number survives the round trip" {
  match gateway_connect() {
    None => ()
    Some(client) => {
      // 2^53 + 1 is the first integer a `Double` cannot hold; the gateway carries it
      // as a decimal string, so the id has to come back bit for bit.
      let wanted = 9007199254740993L
      let granted = client.lease().grant(30L, id=wanted)
      assert_eq(granted.id, wanted)
      let ttl = client.lease().time_to_live(wanted)
      assert_eq(ttl.id, wanted)
      let _ = client.lease().revoke(wanted)
      client.close()
    }
  }
}

///|
async test "gateway: keep-alive holds a lease and reports the same id" {
  match gateway_connect() {
    None => ()
    Some(client) => {
      @async.with_task_group <| g => {
        let granted = client.lease().grant(10L)
        let keep = client.lease().keep_alive(g)
        keep.keep_alive(granted.id)
        let ack = keep.next()
        assert_eq(ack.unwrap().id, granted.id)
        keep.close()
        let _ = client.lease().revoke(granted.id)
      }
      client.close()
    }
  }
}

///|
async test "gateway: a snapshot arrives as a stream of blobs" {
  match gateway_connect() {
    None => ()
    Some(client) => {
      let snapshot = client.maintenance().snapshot()
      assert_true(snapshot.length() >= 1)
      let mut bytes = 0
      for blob in snapshot {
        bytes = bytes + blob.blob.length()
      }
      assert_true(bytes > 0)
      client.close()
    }
  }
}

///|
/// A role, a user and a token over the gateway: the gateway reads the token from the
/// `Authorization` header, so this is the case that would fail if the transport kept
/// sending it as gRPC metadata. Auth is left on only inside this test, and the suite
/// runs one test at a time.
async test "gateway: a token in the authorization header is what lets a user in" {
  guard gateway_connect() is Some(admin) else { return }
  defer admin.close()
  let auth = admin.auth()
  // A server that has seen this test before still has the users, and says so; the
  // password is the same either way, so the message is the only thing to drop.
  try {
    ignore(auth.role_add("moonetcd-gw"))
    ignore(
      auth.role_grant_permission("moonetcd-gw", {
        key: b"/moonetcd-gw/auth/",
        range_end: b"/moonetcd-gw/auth0",
        perm_type: @moonetcd.PermissionType::ReadWrite,
      }),
    )
    ignore(auth.user_add("moonetcd-gw", "secret"))
    ignore(auth.user_grant_role("moonetcd-gw", "moonetcd-gw"))
  } catch {
    _ => ()
  }
  try {
    ignore(auth.user_add("root", "secret"))
    ignore(auth.role_add("root"))
    ignore(auth.user_grant_role("root", "root"))
  } catch {
    _ => ()
  }
  ignore(auth.enable())
  let base = live_config()
  let root = @client.Client::connect_gateway({
    ..base,
    username: "root",
    password: "secret",
  })
  defer {
    @async.protect_from_cancel(() => ignore(root.auth().disable()))
    root.close()
  }
  let user = @client.Client::connect_gateway({
    ..base,
    username: "moonetcd-gw",
    password: "secret",
  })
  defer user.close()
  ignore(user.kv().put(b"/moonetcd-gw/auth/k", b"v"))
  assert_eq(user.kv().get(b"/moonetcd-gw/auth/k").kvs[0].value, b"v")
  let denied = try {
    ignore(user.kv().put(b"/elsewhere", b"v"))
    false
  } catch {
    _ => true
  }
  assert_true(denied)
}

///|
/// The key the gateway writes is the key gRPC reads. A gateway carries keys as base64,
/// so an encoder that loses a byte, pads differently, or picks another alphabet would
/// still agree with itself — and be wrong against the rest of the cluster.
async test "gateway: a key written over the gateway is the same key over gRPC" {
  match (try_connect(), gateway_connect()) {
    (Some(grpc), Some(gateway)) => {
      let from_gateway = b"/moonetcd-gw/across/one"
      let from_grpc = b"/moonetcd-gw/across/two"
      let _ = gateway.kv().put(from_gateway, b"written over JSON")
      let read = grpc.kv().get(from_gateway)
      assert_eq(read.kvs.length(), 1)
      assert_eq(read.kvs[0].key, from_gateway)
      assert_eq(read.kvs[0].value, b"written over JSON")
      let _ = grpc.kv().put(from_grpc, b"written over HTTP/2")
      let back = gateway.kv().get(from_grpc)
      assert_eq(back.kvs.length(), 1)
      assert_eq(back.kvs[0].key, from_grpc)
      assert_eq(back.kvs[0].value, b"written over HTTP/2")
      let keys = grpc.kv().get_prefix(b"/moonetcd-gw/across/")
      assert_eq(keys.kvs.length(), 2)
      let _ = grpc
        .kv()
        .delete_range(@moonetcd.DeleteRangeRequest::{
          ..@moonetcd.DeleteRangeRequest::empty(),
          key: b"/moonetcd-gw/across/",
          range_end: @moonetcd.prefix(b"/moonetcd-gw/across/"),
        })
      grpc.close()
      gateway.close()
    }
    _ => ()
  }
}
