///|
async fn open_sd() -> @client.Client? {
  try_connect()
}

///|
fn endpoint(port : Int32) -> @moonsd.Endpoint {
  @moonsd.Endpoint::new("10.1.0.2", port)
}

///|
async test "a registry meets the discovery contract" {
  guard open_sd() is Some(client) else { return }
  defer client.close()
  let registry = @sd.Registry::new(client)
  @conformance.check(
    registry,
    registry,
    service="moonetcd-sd-\{@env.now()}",
    settle=8000,
  )
}

///|
async test "a service named like a path stays its own service" {
  guard open_sd() is Some(client) else { return }
  defer client.close()
  let registry = @sd.Registry::new(client)
  let lease = @moonsd.Registrar::register(
    registry,
    "sd-path/v2",
    endpoint(1),
    5000,
  )
  defer @async.protect_from_cancel(() => {
    @moonsd.Registrar::deregister(registry, lease)
  })
  assert_eq(@moonsd.Discovery::resolve(registry, "sd-path").length(), 0)
  assert_eq(@moonsd.Discovery::resolve(registry, "sd-path/v2").length(), 1)
}

///|
async test "two prefixes do not see each other" {
  guard open_sd() is Some(client) else { return }
  defer client.close()
  let one = @sd.Registry::new(client, prefix="/sd-one")
  let two = @sd.Registry::new(client, prefix="/sd-two")
  let lease = @moonsd.Registrar::register(one, "sd-pre", endpoint(2), 5000)
  defer @async.protect_from_cancel(() => {
    @moonsd.Registrar::deregister(one, lease)
  })
  assert_eq(@moonsd.Discovery::resolve(one, "sd-pre").length(), 1)
  assert_eq(@moonsd.Discovery::resolve(two, "sd-pre").length(), 0)
}

///|
async test "a value that is not an endpoint is refused" {
  guard open_sd() is Some(client) else { return }
  defer client.close()
  let registry = @sd.Registry::new(client)
  let granted = client.lease().grant(5)
  defer @async.protect_from_cancel(() => {
    ignore(client.lease().revoke(granted.id))
  })
  ignore(client.kv().put(b"/moonsd/sd-bad/x", b"not json", lease=granted.id))
  let refused = try @moonsd.Discovery::resolve(registry, "sd-bad") catch {
    @moonsd.Malformed(_) => true
    _ => false
  } noraise {
    _ => false
  }
  assert_true(refused)
}

///|
async test "a watcher outlives a compaction" {
  guard open_sd() is Some(client) else { return }
  defer client.close()
  let registry = @sd.Registry::new(client)
  let service = "sd-compact"
  let watcher = @moonsd.Discovery::watch(registry, service)
  defer watcher.close()
  let first = watcher.next()
  let a = @moonsd.Registrar::register(registry, service, endpoint(3), 5000)
  defer @async.protect_from_cancel(() => {
    @moonsd.Registrar::deregister(registry, a)
  })
  let b = @moonsd.Registrar::register(registry, service, endpoint(4), 5000)
  defer @async.protect_from_cancel(() => {
    @moonsd.Registrar::deregister(registry, b)
  })
  let top = client.kv().put(b"/moonsd-it/compact", b"x").header.revision
  ignore(client.kv().compact(top))
  // The watcher's position is now behind the compacted history.
  let got = @async.with_timeout_opt(5000, () => {
    let mut update = watcher.next()
    while update.endpoints.length() < 2 {
      update = watcher.next()
    }
    update
  })
  guard got is Some(update) else { fail("the watcher stopped hearing") }
  assert_true(update.revision > first.revision)
}
