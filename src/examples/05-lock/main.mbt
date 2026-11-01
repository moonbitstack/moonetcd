// A distributed mutex: a session's lease holds the lock, so it is released even if the
// holder dies without unlocking. Every call here is unary.
//
//     moon run src/examples/05-lock

///|
async fn main {
  let config = @moonetcd.ClientConfig::{
    ..@moonetcd.default_client_config,
    endpoints: ["127.0.0.1:2379"],
  }
  let client = @client.Client::connect(config)
  let session = @concurrency.Session::new(client, 30L)
  let mutex = @concurrency.Mutex::new(client, session, b"/demo/lock")
  mutex.lock()
  println("lock acquired on lease \{session.lease_id()}")
  mutex.unlock()
  println("lock released")
  session.close()
  client.close()
}
