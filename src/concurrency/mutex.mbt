// Mutex: a distributed lock over the v3lock service, held on a session's lease. Every
// contender of the same `name` queues behind the previous holder; `lock` blocks until
// the key is granted.

///|
/// A distributed mutex named `name`, held by the session's lease. Create it with
/// `Mutex::new`, then `lock` and `unlock`.
pub struct Mutex {
  client : @client.Client
  lease_id : Int64
  name : Bytes
  mut key : Bytes
}

///|
/// Build a mutex over `name`, using `session`'s lease to hold it.
pub fn Mutex::new(
  client : @client.Client,
  session : Session,
  name : Bytes,
) -> Mutex {
  Mutex::{ client, lease_id: session.lease_id(), name, key: b"", }
}

///|
/// Acquire the mutex. Blocks until the lock is granted; then `unlock` releases it.
pub async fn Mutex::lock(self : Mutex) -> Unit raise @client.EtcdError {
  let resp = self.client.lock().lock(self.name, self.lease_id)
  self.key = resp.key
}

///|
/// Release the mutex (a no-op if it is not held).
pub async fn Mutex::unlock(self : Mutex) -> Unit raise @client.EtcdError {
  if self.key.length() > 0 {
    let _ = self.client.lock().unlock(self.key)
    self.key = b""
  }
}
