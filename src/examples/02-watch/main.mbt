// Watch a key, change it, and read the event.
//
//     moon run src/examples/02-watch

///|
async fn main {
  let client = @client.Client::connect({
    ..@moonetcd.default_client_config,
    endpoints: ["127.0.0.1:2379"],
  })
  let key = b"/demo/watched"
  @async.with_task_group(group => {
    let chan = client
      .watch()
      .watch_create(group, { ..@moonetcd.WatchCreateRequest::empty(), key, })
    // The first answer says the watch exists, so a write from here on is seen.
    ignore(chan.next())
    ignore(client.kv().put(key, b"changed"))
    if chan.next() is Some(answer) {
      for event in answer.events {
        println(
          "\{@utf8.decode_lossy(event.kv.key)} = \{@utf8.decode_lossy(event.kv.value)}",
        )
      }
    }
    chan.cancel()
  })
  client.close()
}
