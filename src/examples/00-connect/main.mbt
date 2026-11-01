// Connect to etcd and print the member status.
//
//     moon run src/examples/00-connect

///|
/// The endpoint these examples dial. Start etcd with its default client URL, or point
/// this at the member you run.
let endpoint : String = "127.0.0.1:2379"

///|
async fn main {
  let config = @moonetcd.ClientConfig::{
    ..@moonetcd.default_client_config,
    endpoints: [endpoint],
  }
  let client = @client.Client::connect(config)
  let status = client.maintenance().status()
  println("etcd version : \{status.version}")
  println("db size      : \{status.db_size} bytes")
  println("leader       : \{status.leader}")
  println("raft term    : \{status.raft_term}")
  client.close()
}
