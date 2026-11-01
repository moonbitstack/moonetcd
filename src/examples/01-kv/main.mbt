// Put, read, prefix-scan, and delete keys.
//
//     moon run src/examples/01-kv

///|
async fn main {
  let config = @moonetcd.ClientConfig::{
    ..@moonetcd.default_client_config,
    endpoints: ["127.0.0.1:2379"],
  }
  let client = @client.Client::connect(config)
  let kv = client.kv()
  let _ = kv.put(b"/demo/a", b"alpha")
  let _ = kv.put(b"/demo/b", b"beta")
  let one = kv.get(b"/demo/a")
  for item in one.kvs {
    println(
      "/demo/a = \{@utf8.decode_lossy(item.value[:])} (rev \{item.mod_revision})",
    )
  }
  let under = kv.get_prefix(b"/demo/")
  println("keys under /demo/: \{under.count}")
  let del = kv.delete_range(@moonetcd.DeleteRangeRequest::{
    ..@moonetcd.DeleteRangeRequest::empty(),
    key: b"/demo/",
    range_end: @moonetcd.prefix(b"/demo/"),
  })
  println("deleted: \{del.deleted}")
  client.close()
}
