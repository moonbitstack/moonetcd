// The same calls over etcd's HTTP/JSON gateway instead of gRPC: keys travel as
// base64, and a watch reads events as the server sends them.
//
//     moon run src/examples/06-gateway

///|
async fn main {
  let config = @moonetcd.ClientConfig::{
    ..@moonetcd.default_client_config,
    endpoints: ["127.0.0.1:2379"],
  }
  let client = @client.Client::connect_gateway(config)
  let kv = client.kv()
  let _ = kv.put(b"/demo/gateway", b"over JSON")
  let one = kv.get(b"/demo/gateway")
  for item in one.kvs {
    println(
      "/demo/gateway = \{@utf8.decode_lossy(item.value[:])} (rev \{item.mod_revision})",
    )
  }
  @async.with_task_group <| g => {
    let chan = client
      .watch()
      .watch_create(g, @moonetcd.WatchCreateRequest::{
        ..@moonetcd.WatchCreateRequest::empty(),
        key: b"/demo/gateway",
      })
    let _ = chan.next()
    let _ = kv.put(b"/demo/gateway", b"changed")
    match chan.next() {
      Some(response) =>
        for event in response.events {
          println("event: \{@utf8.decode_lossy(event.kv.value[:])}")
        }
      None => println("the watch ended")
    }
    chan.cancel()
  }
  let _ = kv.delete_range(@moonetcd.DeleteRangeRequest::{
    ..@moonetcd.DeleteRangeRequest::empty(),
    key: b"/demo/gateway",
  })
  let status = client.maintenance().status()
  println("member \{status.version}, db \{status.db_size} bytes")
  client.close()
}
