// Grant a lease, attach a key to it, inspect it, then revoke it.
//
//     moon run src/examples/03-lease

///|
async fn main {
  let config = @moonetcd.ClientConfig::{
    ..@moonetcd.default_client_config,
    endpoints: ["127.0.0.1:2379"],
  }
  let client = @client.Client::connect(config)
  let lease = client.lease()
  let granted = lease.grant(30L)
  println("granted lease \{granted.id} for \{granted.ttl}s")
  let _ = client.kv().put(b"/demo/ephemeral", b"alive", lease=granted.id)
  let ttl = lease.time_to_live(granted.id, keys=true)
  println("ttl \{ttl.ttl}s, guarding \{ttl.keys.length()} key(s)")
  let _ = lease.revoke(granted.id)
  println("revoked \{granted.id}")
  client.close()
}
