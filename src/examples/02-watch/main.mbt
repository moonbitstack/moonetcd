// Watch a key and read the events a Put produces. The watch runs on its own
// multiplexed channel inside a task group, and reconnects from the last revision
// if the connection drops.
//
//     moon run src/examples/02-watch

///|
async fn main {
  let config = @moonetcd.ClientConfig::{
    ..@moonetcd.default_client_config,
    endpoints: ["127.0.0.1:2379"],
  }
  let client = @client.Client::connect(config)
  @async.with_task_group <| g => {
    let req = @moonetcd.WatchCreateRequest::{
      ..@moonetcd.WatchCreateRequest::empty(),
      key: b"/demo/watched",
    }
    let chan = client.watch().watch_create(g, req)
    let _ = client.kv().put(b"/demo/watched", b"changed")
    let mut seen = 0
    while seen < 2 {
      match chan.next() {
        Some(resp) => {
          println(
            "watch rev \{resp.header.revision}: \{resp.events.length()} event(s), created=\{resp.created}",
          )
          seen = seen + 1
        }
        None => {
          println("watch ended")
          break
        }
      }
    }
    chan.cancel()
  }
  client.close()
}
