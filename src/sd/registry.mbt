// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// Service discovery on etcd: an endpoint is a key attached to a lease, so the key goes when the
// lease does, and the revision etcd gives every write is the watcher's position.

///|
/// What every key of a registry starts with.
pub let prefix : String = "/moonsd"

///|
/// A registry over one etcd client. It is both a `Registrar` and a `Discovery`.
pub struct Registry {
  client : @client.Client
  prefix : String
}

///|
pub fn Registry::new(
  client : @client.Client,
  prefix~ : String = prefix,
) -> Registry {
  { client, prefix, }
}

///|
/// A service's keys. The name is escaped because a prefix read would otherwise take service
/// `a/b` for part of service `a`.
fn Registry::root(self : Registry, service : String) -> Bytes {
  let name = service
    .replace_all(old="%", new="%25")
    .replace_all(old="/", new="%2F")
  @utf8.encode("\{self.prefix}/\{name}/")
}

///|
/// A lease lasts whole seconds, and rounding down would end one early.
fn seconds(ttl : Int32) -> Int64 {
  ((ttl + 999) / 1000).to_int64()
}

///|
pub extend Registry with @moonsd.Registrar::{register, renew, deregister}

///|
pub impl @moonsd.Registrar for Registry with fn register(
  self,
  service,
  endpoint,
  ttl,
) {
  let granted = self.client.lease().grant(seconds(ttl))
  let key = [..self.root(service), ..@utf8.encode(endpoint.id)]
  let value = @utf8.encode(endpoint.to_json().stringify())
  ignore(self.client.kv().put(Bytes::from_array(key), value, lease=granted.id))
  { service, endpoint, ttl, token: granted.id.to_string(), }
}

///|
fn lease_id(lease : @moonsd.Lease) -> Int64 raise @moonsd.Refused {
  @string.parse_int64(lease.token) catch {
    _ => raise @moonsd.Malformed(lease.token)
  }
}

///|
/// One keep-alive. An acknowledgement with no time left means the lease is gone, which is what
/// etcd answers instead of an error.
pub impl @moonsd.Registrar for Registry with fn renew(self, lease) {
  let id = lease_id(lease)
  let mut left = 0L
  @async.with_task_group(g => {
    let stream = self.client.lease().keep_alive(g)
    defer stream.close()
    stream.keep_alive(id)
    if stream.next() is Some(answer) {
      left = answer.ttl
    }
  })
  if left <= 0L {
    raise @moonsd.Expired(lease)
  }
}

///|
/// A lease that has already ended is what this call was after.
pub impl @moonsd.Registrar for Registry with fn deregister(self, lease) {
  let id = lease_id(lease)
  ignore(self.client.lease().revoke(id)) catch {
    @moonetcd.Refused({ code: 5, .. }) => ()
    e => raise e
  }
}

///|
/// A service as it stands at one revision, by id.
async fn Registry::look(
  self : Registry,
  service : String,
) -> (Array[@moonsd.Endpoint], Int64) {
  let answer = self.client.kv().get_prefix(self.root(service))
  let out : Array[@moonsd.Endpoint] = []
  for kv in answer.kvs {
    let text = @utf8.decode_lossy(kv.value)
    let parsed = @json.parse(text) catch { _ => raise @moonsd.Malformed(text) }
    let endpoint : @moonsd.Endpoint = @json.from_json(parsed) catch {
      _ => raise @moonsd.Malformed(text)
    }
    out.push(endpoint)
  }
  out.sort_by_key(e => e.id)
  (out, answer.header.revision)
}

///|
pub extend Registry with @moonsd.Discovery::{resolve, watch}

///|
pub impl @moonsd.Discovery for Registry with fn resolve(self, service) {
  self.look(service).0
}

///|
/// One service followed. Each `next` watches from just past the revision it last reported, in a
/// task group of its own, and answers with a fresh read, so a watch that a compaction or a
/// dropped connection ends costs one more read and nothing else.
priv struct Follower {
  registry : Registry
  service : String
  mut revision : Int64?
  mut closed : Bool
}

///|
/// Wait for a change past `revision`, or for the watch to end: etcd cancels one whose start has
/// been compacted away, and the fresh read that follows is the answer to that too.
async fn Follower::changed(self : Follower, revision : Int64) -> Unit {
  let (key, range_end) = @moonetcd.prefix_range(
    self.registry.root(self.service),
  )
  let request = @moonetcd.WatchCreateRequest::{
    ..@moonetcd.WatchCreateRequest::empty(),
    key,
    range_end,
    start_revision: revision + 1,
  }
  @async.with_task_group(g => {
    let chan = self.registry.client.watch().watch_create(g, request)
    for ;; {
      match chan.next() {
        Some(answer) if answer.events.is_empty() && !answer.canceled => ()
        _ => break
      }
    }
    chan.cancel()
  })
}

///|
impl @moonsd.Watcher for Follower with fn next(self) {
  for ;; {
    if self.closed {
      fail("the watcher is closed")
    }
    if self.revision is Some(revision) {
      self.changed(revision)
    }
    let (endpoints, revision) = self.registry.look(self.service)
    self.revision = Some(revision)
    return { endpoints, revision, }
  }
}

///|
impl @moonsd.Watcher for Follower with fn close(self) {
  self.closed = true
}

///|
pub impl @moonsd.Discovery for Registry with fn watch(self, service) {
  let follower : &@moonsd.Watcher = Follower::{
    registry: self,
    service,
    revision: None,
    closed: false,
  }
  follower
}
