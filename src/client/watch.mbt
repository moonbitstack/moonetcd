// Watch: a bidi stream of key-change events. The handle opens its own multiplexed
// channel (so it survives a disconnect that kills the unary path) and, on a dropped
// stream, reconnects to the next endpoint and re-issues the create with a start
// revision just past the last event it saw — exactly the resume clientv3 does.

///|
/// A typed handle for the Watch service. Obtain it with `client.watch()`.
pub struct Watch {
  client : Client
}

///|
/// An open watch. Pull events with `next`; cancel it with `cancel`.
pub struct WatchChan {
  client : Client
  g : @async.TaskGroup[Unit]
  mut mux : @net.MuxChannel
  mut bidi : @net.BidiStream
  mut create : WatchCreateRequest
  mut last_revision : Int64
  mut watch_id : Int64
  mut endpoint_idx : Int32
  mut reconnects : Int32
  mut closed : Bool
}

///|
/// Open a watch for `req`. The call runs inside `@async.with_task_group`, whose group
/// `g` drives the channel's read pump — pass it in so a reconnect can respawn one.
pub async fn Watch::watch_create(
  self : Watch,
  g : @async.TaskGroup[Unit],
  req : WatchCreateRequest,
) -> WatchChan raise EtcdError {
  let ep = self.client.endpoint_at(0)
  let mux = @net.MuxChannel::connect(ep.0, ep.1) catch {
    _ => raise transport_error("watch dial")
  }
  g.spawn_bg(() => mux.read_pump())
  let bidi = mux.open_bidi("/etcdserverpb.Watch/Watch")
  let ch = WatchChan::{
    client: self.client,
    g,
    mux,
    bidi,
    create: req,
    last_revision: req.start_revision,
    watch_id: 0,
    endpoint_idx: 0,
    reconnects: 0,
    closed: false,
  }
  ch.send_create()
  ch
}

///|
/// (Re)send the current create request on the active stream.
async fn WatchChan::send_create(self : WatchChan) -> Unit raise EtcdError {
  self.bidi.send(self.create.encode()) catch {
    _ => raise transport_error("watch send create")
  }
}

///|
/// The next `WatchResponse`, or `None` once the watch is cancelled. If the stream drops,
/// reconnect from the last revision (on the next endpoint) and continue — capped so a
/// permanently broken cluster does not loop forever.
pub async fn WatchChan::next(
  self : WatchChan,
) -> WatchResponse? raise EtcdError {
  for ;; {
    if self.closed {
      return None
    }
    let raw = self.bidi.recv() catch {
      _ => raise transport_error("watch recv")
    }
    match raw {
      Some(bytes) => {
        let resp = WatchResponse::decode(bytes) catch {
          _ =>
            raise @moonetcd.EtcdError::Refused(@moonetcd.Status::{
              code: 13,
              message: "decode WatchResponse failed",
            })
        }
        if resp.watch_id != 0 {
          self.watch_id = resp.watch_id
        }
        if resp.header.revision > self.last_revision {
          self.last_revision = resp.header.revision
        }
        return Some(resp)
      }
      None => {
        if self.reconnects >= 3 {
          self.closed = true
          return None
        }
        self.reconnects = self.reconnects + 1
        self.reconnect()
      }
    }
  }
}

///|
/// Reconnect to the next endpoint and resume the watch from just after the last event.
async fn WatchChan::reconnect(self : WatchChan) -> Unit raise EtcdError {
  self.mux.close()
  self.endpoint_idx = self.endpoint_idx + 1
  let ep = self.client.endpoint_at(self.endpoint_idx)
  let mux = @net.MuxChannel::connect(ep.0, ep.1) catch {
    _ => raise transport_error("watch reconnect dial")
  }
  self.g.spawn_bg(() => mux.read_pump())
  let bidi = mux.open_bidi("/etcdserverpb.Watch/Watch")
  self.mux = mux
  self.bidi = bidi
  let resume_rev = if self.last_revision > 0 {
    self.last_revision + 1
  } else {
    0
  }
  self.create = { ..self.create, start_revision: resume_rev, }
  self.send_create()
}

///|
/// Cancel the watch and close its connection.
pub async fn WatchChan::cancel(self : WatchChan) -> Unit {
  self.closed = true
  try {
    self.bidi.send(
      @moonetcd.WatchCancelRequest::{ watch_id: self.watch_id, }.encode(),
    )
    self.bidi.close_send()
  } catch {
    _ => ()
  }
  self.mux.close()
}
