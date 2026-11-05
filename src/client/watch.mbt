// Watch: a stream of key-change events, over whichever transport the client uses.
// The handle only knows the stream's two verbs — the next reply and stop — because
// everything that differs between the transports (a bidi channel here, one HTTP
// request there) happens below, including resuming from the last revision.

///|
/// A typed handle for the Watch service. Obtain it with `client.watch()`.
pub struct Watch {
  client : Client
}

///|
/// An open watch. Pull events with `next`; end it with `cancel`.
pub struct WatchChan {
  stream : &WatchStream
  mut closed : Bool
}

///|
/// Open a watch for `request`. The call runs inside `@async.with_task_group`, whose
/// group `g` carries the stream's background work — pass it in so the transport can
/// read the connection while the caller waits for events.
pub async fn Watch::watch_create(
  self : Watch,
  g : @async.TaskGroup[Unit],
  request : WatchCreateRequest,
) -> WatchChan raise EtcdError {
  let stream = self.client.watch_stream(g, request)
  { stream, closed: false, }
}

///|
/// The next `WatchResponse`, or `None` once the watch has ended.
pub async fn WatchChan::next(
  self : WatchChan,
) -> WatchResponse? raise EtcdError {
  if self.closed {
    return None
  }
  self.stream.next()
}

///|
/// End the watch and release its connection.
pub fn WatchChan::cancel(self : WatchChan) -> Unit {
  self.closed = true
  self.stream.close()
}
