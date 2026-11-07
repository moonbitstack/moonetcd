// What a server does over time: leases running out, locks changing hands, history compacted,
// and members dying under a client. The tests that kill a member need the three members of
// `scripts/etcd_cluster.sh`, named by `MOONETCD_MEMBERS`; without it they return.

///|
async fn open_scenario() -> @client.Client? {
  try_connect()
}

///|
/// The command that stops and starts members, when the suite is allowed to.
fn members_command() -> String? {
  @env.get_env_var("MOONETCD_MEMBERS")
}

///|
async fn on_member(command : String, action : String, name : String) -> Unit {
  let code = @process.run("sh", ["-c", "\{command} \{action} \{name}"])
  if code != 0 {
    fail("\{action} \{name} exited with \{code}")
  }
}

///|
async fn three_members() -> @client.Client {
  @client.Client::connect({
    ..@moonetcd.default_client_config,
    endpoints: ["127.0.0.1:32379", "127.0.0.1:22379", "127.0.0.1:2379"],
  })
}

///|
async fn only(endpoint : String) -> @client.Client {
  @client.Client::connect({
    ..@moonetcd.default_client_config,
    endpoints: [endpoint],
  })
}

///|
/// Write through an election: a member answers `UNAVAILABLE` until a new leader is up, and such
/// a write may still land, so a value can arrive twice.
async fn persist(c : @client.Client, key : Bytes, value : Bytes) -> Unit {
  for _ in 0..<100 {
    let landed = try {
      ignore(c.kv().put(key, value))
      true
    } catch {
      @moonetcd.Refused({ code: 14, .. }) => false
      e => raise e
    }
    if landed {
      return
    }
    @async.sleep(100)
  }
  fail("no leader within ten seconds")
}

///|
/// Keep trying `check` until it holds, for what a server does in its own time.
async fn eventually(
  what : String,
  limit : Int32,
  check : async () -> Bool,
) -> Unit {
  for _ in 0..<(limit / 50) {
    if check() {
      return
    }
    @async.sleep(50)
  }
  fail("not within \{limit} ms: \{what}")
}

///|
async test "a lease kept alive outlives its ttl, and left alone it takes its keys" {
  guard open_scenario() is Some(c) else { return }
  defer c.close()
  let key = b"/moonetcd-it/lease/kept"
  let granted = c.lease().grant(2)
  ignore(c.kv().put(key, b"v", lease=granted.id))
  @async.with_task_group(g => {
    let stream = c.lease().keep_alive(g)
    defer stream.close()
    for _ in 0..<8 {
      stream.keep_alive(granted.id)
      guard stream.next() is Some(answer) else { fail("the stream ended") }
      assert_true(answer.ttl > 0)
      @async.sleep(500)
    }
  })
  assert_eq(c.kv().get(key).kvs.length(), 1)
  eventually("the key to go with the lease", 8000, () => {
    c.kv().get(key).kvs.is_empty()
  })
  assert_eq(c.lease().time_to_live(granted.id).ttl, -1)
}

///|
async test "a keep-alive on a lease that has ended says so" {
  guard open_scenario() is Some(c) else { return }
  defer c.close()
  let granted = c.lease().grant(5)
  ignore(c.lease().revoke(granted.id))
  let mut left = -1L
  @async.with_task_group(g => {
    let stream = c.lease().keep_alive(g)
    defer stream.close()
    stream.keep_alive(granted.id)
    if stream.next() is Some(answer) {
      left = answer.ttl
    }
  })
  assert_eq(left, 0)
}

///|
async test "history compacted away is refused for a read and ends a watch" {
  guard open_scenario() is Some(c) else { return }
  defer c.close()
  let key = b"/moonetcd-it/compacted"
  let first = c.kv().put(key, b"1").header.revision
  let top = c.kv().put(key, b"2").header.revision
  ignore(c.kv().compact(top))
  let refused = try {
    ignore(
      c.kv().range({ ..@moonetcd.RangeRequest::empty(), key, revision: first, }),
    )
    false
  } catch {
    @moonetcd.Compacted(_) => true
    _ => false
  }
  assert_true(refused)
  let ahead = try {
    ignore(
      c
      .kv()
      .range({
        ..@moonetcd.RangeRequest::empty(),
        key,
        revision: top + 1000000,
      }),
    )
    false
  } catch {
    @moonetcd.FutureRev(_) => true
    _ => false
  }
  assert_true(ahead)
  @async.with_task_group(g => {
    let chan = c
      .watch()
      .watch_create(g, {
        ..@moonetcd.WatchCreateRequest::empty(),
        key,
        start_revision: first,
      })
    let mut canceled = false
    for _ in 0..<4 {
      guard chan.next() is Some(answer) else { break }
      if answer.canceled {
        assert_true(answer.compact_revision >= top)
        canceled = true
        break
      }
    }
    chan.cancel()
    assert_true(canceled)
  })
}

///|
async test "a lock is held by one session at a time" {
  guard open_scenario() is Some(c) else { return }
  defer c.close()
  let one = @concurrency.Session::new(c, 10)
  let two = @concurrency.Session::new(c, 10)
  let first = @concurrency.Mutex::new(c, one, b"/moonetcd-it/lock/held")
  let second = @concurrency.Mutex::new(c, two, b"/moonetcd-it/lock/held")
  first.lock()
  let got_it = Ref(false)
  @async.with_task_group(g => {
    g.spawn_bg(() => {
      second.lock()
      got_it.val = true
    })
    @async.sleep(500)
    assert_false(got_it.val)
    first.unlock()
    eventually("the second session to get the lock", 3000, () => got_it.val)
  })
  second.unlock()
  one.close()
  two.close()
}

///|
async test "a lock goes when the session holding it does" {
  guard open_scenario() is Some(c) else { return }
  defer c.close()
  let holder = @concurrency.Session::new(c, 10)
  let waiter = @concurrency.Session::new(c, 10)
  let held = @concurrency.Mutex::new(c, holder, b"/moonetcd-it/lock/expired")
  let waiting = @concurrency.Mutex::new(c, waiter, b"/moonetcd-it/lock/expired")
  held.lock()
  let got_it = Ref(false)
  @async.with_task_group(g => {
    g.spawn_bg(() => {
      waiting.lock()
      got_it.val = true
    })
    @async.sleep(300)
    assert_false(got_it.val)
    holder.close()
    eventually("the lock to pass on", 3000, () => got_it.val)
  })
  waiting.unlock()
  waiter.close()
}

///|
async test "leadership passes to the next campaign when the leader resigns" {
  guard open_scenario() is Some(c) else { return }
  defer c.close()
  let first = @concurrency.Session::new(c, 10)
  let second = @concurrency.Session::new(c, 10)
  let name = b"/moonetcd-it/election/handover"
  let a = @concurrency.Election::new(c, first, name)
  let b = @concurrency.Election::new(c, second, name)
  a.campaign(b"a")
  assert_eq(a.current_leader().value, b"a")
  a.proclaim(b"a2")
  assert_eq(a.current_leader().value, b"a2")
  let won = Ref(false)
  @async.with_task_group(g => {
    g.spawn_bg(() => {
      b.campaign(b"b")
      won.val = true
    })
    @async.sleep(300)
    assert_false(won.val)
    a.resign()
    eventually("the second campaign to win", 3000, () => won.val)
  })
  assert_eq(b.current_leader().value, b"b")
  b.resign()
  first.close()
  second.close()
}

///|
async test "many tasks share one client" {
  guard open_scenario() is Some(c) else { return }
  defer c.close()
  @async.with_task_group(g => {
    for i in 0..<8 {
      g.spawn_bg(() => {
        let key = @utf8.encode("/moonetcd-it/shared/\{i}")
        for j in 0..<10 {
          let value = @utf8.encode("\{j}")
          ignore(c.kv().put(key, value))
          assert_eq(c.kv().get(key).kvs[0].value, value)
          let granted = c.lease().grant(5)
          ignore(c.lease().revoke(granted.id))
        }
      })
    }
  })
}

///|
/// Tests run side by side and the others connect to m1, so this kills m3, which `three_members`
/// tries first. It is one test because two members down at once would lose the quorum.
async test "a member dying leaves a watch where it was and moves calls to the next member" {
  guard members_command() is Some(command) else { return }
  guard open_scenario() is Some(probe) else { return }
  probe.close()
  let c = three_members()
  defer c.close()
  let other = only("127.0.0.1:22379")
  defer other.close()
  let key = b"/moonetcd-it/member/dying"
  ignore(c.kv().put(key, b"start"))
  @async.with_task_group(g => {
    let chan = c
      .watch()
      .watch_create(g, { ..@moonetcd.WatchCreateRequest::empty(), key, })
    ignore(chan.next())
    ignore(other.kv().put(key, b"before"))
    guard chan.next() is Some(first) else { fail("the watch ended") }
    assert_eq(first.events[0].kv.value, b"before")
    on_member(command, "stop", "m3")
    persist(other, key, b"missed")
    persist(other, key, b"after")
    let seen : Array[Bytes] = []
    let done = @async.with_timeout_opt(15000, () => {
      while seen.last() != Some(b"after") {
        guard chan.next() is Some(answer) else { fail("the watch ended") }
        for event in answer.events {
          seen.push(event.kv.value)
        }
      }
    })
    assert_true(done is Some(_))
    assert_eq(seen[0], b"missed")
    chan.cancel()
  })
  // A read is safe to send again, so it needs nothing from the caller.
  assert_eq(c.kv().get(key).kvs[0].value, b"after")
  // The read moved the client on, so a write goes straight to a member that is up.
  persist(c, key, b"written")
  assert_eq(other.kv().get(key).kvs[0].value, b"written")
  on_member(command, "start", "m3")
}

///|
/// Roles, users and a token against a real server. Auth stays on only inside this test, and the
/// suite runs one test at a time, so the other tests never meet it.
async test "a role grants what it says, and a token is what lets a user in" {
  guard open_scenario() is Some(c) else { return }
  defer c.close()
  let auth = c.auth()
  ignore(auth.role_add("moonetcd-it"))
  ignore(
    auth.role_grant_permission("moonetcd-it", {
      key: b"/moonetcd-it/auth/",
      range_end: b"/moonetcd-it/auth0",
      perm_type: ReadWrite,
    }),
  )
  let role = auth.role_get("moonetcd-it")
  assert_eq(role.perm.length(), 1)
  assert_eq(role.perm[0].key, b"/moonetcd-it/auth/")
  assert_eq(role.perm[0].range_end, b"/moonetcd-it/auth0")
  assert_true(role.perm[0].perm_type == ReadWrite)
  ignore(auth.user_add("root", "secret"))
  ignore(auth.role_add("root"))
  ignore(auth.user_grant_role("root", "root"))
  ignore(auth.user_add("moonetcd-it", "secret"))
  ignore(auth.user_grant_role("moonetcd-it", "moonetcd-it"))
  assert_eq(auth.user_get("moonetcd-it").roles, ["moonetcd-it"])
  ignore(auth.enable())
  let base = live_config()
  let admin = @client.Client::connect({
    ..base,
    username: "root",
    password: "secret",
  })
  defer {
    @async.protect_from_cancel(() => ignore(admin.auth().disable()))
    admin.close()
  }
  let user = @client.Client::connect({
    ..base,
    username: "moonetcd-it",
    password: "secret",
  })
  defer user.close()
  ignore(user.kv().put(b"/moonetcd-it/auth/k", b"v"))
  assert_eq(user.kv().get(b"/moonetcd-it/auth/k").kvs[0].value, b"v")
  let denied = try {
    ignore(user.kv().put(b"/elsewhere", b"v"))
    false
  } catch {
    _ => true
  }
  assert_true(denied)
}

///|
async test "a snapshot comes back whole" {
  guard open_scenario() is Some(c) else { return }
  defer c.close()
  let chunks = c.maintenance().snapshot()
  assert_true(chunks.length() > 0)
  let total = chunks.fold(init=0, (sum, chunk) => sum + chunk.blob.length())
  assert_true(total > 1000)
  assert_eq(chunks[chunks.length() - 1].remaining_bytes, 0)
}
