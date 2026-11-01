// Lock: the v3lock service — a distributed mutex built on a lease, with each waiter
// parked on a key ordered before the previous holder.

///|
/// A typed handle for the Lock service. Obtain it with `client.lock()`.
pub struct Lock {
  client : Client
}

///|
/// Acquire the lock named `name`. The returned `key` is what `unlock` takes; `name`
/// is the lock's identity, shared by every contender.
pub async fn Lock::lock(
  self : Lock,
  name : Bytes,
  lease : Int64,
) -> LockResponse raise EtcdError {
  let req = @moonetcd.LockRequest::{ name, lease, }
  self.client.rpc(
    "/v3lockpb.Lock/Lock",
    req.encode(),
    @moonetcd.LockResponse::decode,
  )
}

///|
/// Release the lock whose key `key` was returned by `lock`.
pub async fn Lock::unlock(
  self : Lock,
  key : Bytes,
) -> UnlockResponse raise EtcdError {
  let req = @moonetcd.UnlockRequest::{ key, }
  self.client.rpc(
    "/v3lockpb.Lock/Unlock",
    req.encode(),
    @moonetcd.UnlockResponse::decode,
  )
}
