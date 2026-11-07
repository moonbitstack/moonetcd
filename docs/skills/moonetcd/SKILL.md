---
name: moonetcd
description: "Read and write an etcd v3 cluster from MoonBit: keys, transactions, watches, leases, locks, leader election and member administration, over gRPC or over etcd's HTTP/JSON gateway, with or without TLS. Use when a program needs a configuration store, a distributed lock, a lease, or service discovery backed by etcd."
---

# moonetcd

## Install

```
moon add moonbitstack/moonetcd
```

The message types build on every target; the transports open sockets and are native only.

```
import {
  "moonbitstack/moonetcd",
  "moonbitstack/moonetcd/client",
  "moonbitlang/async",
}
```

## Connect, then use a handle

`Client::connect` dials over gRPC. One client hands out a handle per etcd service — `kv`,
`watch`, `lease`, `cluster`, `auth`, `maintenance`, `lock`, `election` — and every call raises
`@moonetcd.EtcdError`.

```mbt native
async fn main {
  let config = @moonetcd.ClientConfig::{
    ..@moonetcd.default_client_config,
    endpoints: ["127.0.0.1:2379"],
  }
  let client = @client.Client::connect(config)
  let _ = client.kv().put(b"/greeting", b"hello")
  let read = client.kv().get(b"/greeting")
  for item in read.kvs {
    println(@utf8.decode_lossy(item.value[:]))
  }
  client.close()
}
```

`endpoints` takes several members: a read that meets a dead one goes again on the next, and a
watch moves there and resumes from the revision it had reached. A write answers `UNAVAILABLE`
instead of repeating, since it may already have run.

## Watch, and lease

A watch and a lease keep-alive are streams. A watch needs the task group its read pump runs in,
so open it inside `@async.with_task_group`.

```mbt native
async fn watch_one(client : @client.Client) -> Unit {
  @async.with_task_group <| g => {
    let chan = client.watch().watch_create(g, @moonetcd.WatchCreateRequest::{
      ..@moonetcd.WatchCreateRequest::empty(),
      key: b"/greeting",
    })
    let _ = chan.next()                     // the create is acknowledged
    let _ = client.kv().put(b"/greeting", b"changed")
    match chan.next() {
      Some(reply) =>
        for event in reply.events {
          println(@utf8.decode_lossy(event.kv.value[:]))
        }
      None => println("the watch ended")
    }
    chan.cancel()
  }
}
```

```mbt native
async fn leased(client : @client.Client) -> Unit {
  @async.with_task_group <| g => {
    let granted = client.lease().grant(30L)
    let _ = client.kv().put(b"/leased", b"v", lease=granted.id)
    let stream = client.lease().keep_alive(g)
    stream.keep_alive(granted.id)
    match stream.next() {
      Some(answer) => println("ttl \{answer.ttl}")
      None => ()
    }
    stream.close()
    let _ = client.lease().revoke(granted.id)
  }
}
```

A key on a lease goes when the lease does. `@concurrency.Session` wraps that for a lock:
`Mutex::lock` and `unlock` over the `v3lock` service, `Election` over `v3election`.

## TLS

Fill `TlsConfig` and both transports dial TLS. `ca_cert` is a PEM bundle or one DER
certificate and defaults to the public roots; `cert` and `key` are the client's own certificate
and key for a member that asks for one; `server_name` is the name the member's certificate has
to carry, the endpoint's own host when empty.

```mbt native
async fn secure(endpoint : String, ca : Bytes) -> @client.Client {
  @client.Client::connect({
    ..@moonetcd.default_client_config,
    endpoints: [endpoint],
    tls: @moonetcd.TlsConfig::{
      enabled: true,
      ca_cert: ca,
      cert: b"",
      key: b"",
      server_name: "",
    },
  })
}
```

The gRPC transport offers `h2` and nothing else; the gateway offers no protocol at all, which
is what leaves etcd serving it HTTP/1.1.

`@client.Client::connect_gateway` is the same client over etcd's HTTP/JSON gateway: one `POST`
per call, keys and values in base64, 64-bit integers as strings. Nothing else changes —
`Client::of_transport` takes a transport of your own if you have one.

## What catches people out

- Both constructors raise `EtcdError`: a CA or a key that does not parse is refused at connect
  time, not at the first call.
- `watch_create` and `keep_alive` must run inside `@async.with_task_group`; the group owns the
  connection's read pump, and cancelling the stream is what ends the watch on the server.
- A `WatchResponse` with a non-zero `compact_revision` means the revision asked for is gone;
  read the key again instead of resuming from there.
- `EtcdError::Compacted` and `FutureRev` carry the revision; matching on them is how a caller
  tells "read it again" from "the cluster is behind".
- The gateway's keep-alive is one request and one acknowledgement, so `next()` reports what the
  last `keep_alive(id)` was told rather than a stream of renewals.
