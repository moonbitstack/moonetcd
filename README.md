# moonetcd

An etcd v3 client for MoonBit — the feature surface of etcd's official Go client
(`clientv3`), reimplemented over real gRPC.

`moonetcd` speaks the etcd v3 gRPC API (`etcdserverpb`, `mvccpb`, `v3lock`,
`v3election`) over HTTP/2 via [`moonrpc`](https://github.com/moonbitstack/moonrpc).
It gives you the whole client: key-value reads and writes, transactions, watches
that survive a dropped connection, leases and keep-alives, cluster and auth
administration, maintenance, and the client-side `concurrency` helpers (sessions,
mutexes, leader election).

## Layout

| Package | Contents |
| --- | --- |
| `moonbitstack/moonetcd` | Protobuf message types and codecs for the etcd v3 API, plus key helpers and the error model. Pure data — builds on every target. |
| `moonbitstack/moonetcd/client` | The gRPC transport: `Client`, `KV`, `Watch`, `Lease`, `Cluster`, `Auth`, `Maintenance`, `Lock`, `Election`. Native only. |
| `moonbitstack/moonetcd/concurrency` | `Session`, `Mutex`, `Election` built on the client. Native only. |
| `moonbitstack/moonetcd/examples/...` | Runnable examples (see below). |

The root package carries no transport, so a program on any target can decode etcd
messages; the transport and the concurrency helpers open sockets and are native only.

## Install

```sh
moon add moonbitstack/moonetcd
```

## Quick start

```moonbit
async fn main {
  let config = @moonetcd.ClientConfig::{
    ..@moonetcd.default_client_config,
    endpoints: ["127.0.0.1:2379"],
  }
  let client = @client.Client::connect(config)

  let _ = client.kv().put(b"/greeting", b"hello")
  let resp = client.kv().get(b"/greeting")
  for item in resp.kvs {
    println("value = \{@utf8.decode_lossy(item.value[:])}")
  }
  client.close()
}
```

A `Client` dials one or more endpoints. Unary and server/client-streaming calls go
through a load-balanced channel that fails over across the endpoints; a Watch or a
Lease KeepAlive opens its own multiplexed connection so it can reconnect on its own.

## API surface

`Client` hands out one typed handle per etcd service.

### KV — `client.kv()`

| Method | RPC |
| --- | --- |
| `put(key, value, lease?, prev_kv?)` | `Put` |
| `get(key)`, `get_prefix(prefix)` | `Range` |
| `range(RangeRequest)` | `Range` |
| `delete_range(DeleteRangeRequest)` | `DeleteRange` |
| `txn(TxnRequest)` | `Txn` |
| `compact(revision, physical?)` | `Compact` |

`RangeRequest` carries every lever of the gRPC message — `range_end`, `limit`,
`revision`, `sort_order`, `sort_target`, `serializable`, `keys_only`, `count_only`,
the four `min`/`max` revision bounds, and `progress_notify`.

### Watch — `client.watch()`

`watch_create(task_group, WatchCreateRequest)` opens a bidi stream on its own
multiplexed channel and returns a `WatchChan`. `WatchChan::next()` blocks until the
next `WatchResponse` (or `None` once cancelled). If the stream drops — a failed
member, a network blip — it reconnects to the next configured endpoint and re-issues
the create with `start_revision` set just past the last event it saw, so no event is
lost. A `WatchResponse` with a non-zero `compact_revision` means the requested
revision was compacted; check it on the response.

```moonbit
@async.with_task_group <| g => {
  let chan = client.watch().watch_create(
    g,
    @moonetcd.WatchCreateRequest::{ ..@moonetcd.WatchCreateRequest::empty(), key: b"/watched" },
  )
  match chan.next() {
    Some(resp) => println("revision \{resp.header.revision}, \{resp.events.length()} event(s)")
    None => println("watch ended")
  }
  chan.cancel()
}
```

The task group drives the channel's read pump, so a watch (and a keep-alive) must
open inside `@async.with_task_group`.

### Lease — `client.lease()`

| Method | RPC |
| --- | --- |
| `grant(ttl, id?)` | `LeaseGrant` |
| `revoke(id)` | `LeaseRevoke` |
| `time_to_live(id, keys?)` | `LeaseTimeToLive` |
| `leases()` | `LeaseLeases` |
| `keep_alive(task_group)` | `LeaseKeepAlive` (bidi) |

`KeepAlive` is a bidi stream: `keep_alive(id)` sends a keep-alive request, `next()`
reads the acknowledgement, `close()` ends it. Attach a key to a lease by passing
`lease = lease_id` to `KV::put`.

### Cluster — `client.cluster()`

`member_add(peer_urls, is_learner?)`, `member_remove(id)`, `member_update(id,
peer_urls)`, `member_list(linearizable?)`, `member_promote(id)`.

### Auth — `client.auth()`

`enable()`, `disable()`, `status()`, `user_add`, `user_delete`,
`user_change_password`, `user_grant_role`, `user_revoke_role`, `user_get`,
`user_list`, `role_add`, `role_delete`, `role_grant_permission`,
`role_revoke_permission`, `role_get`, `role_list`.

When a `ClientConfig` carries a username and password, `Client::connect`
authenticates and injects the returned token as the `token` metadata header on every
call.

### Maintenance — `client.maintenance()`

`status()`, `alarm(action, member_id, alarm)`, `defragment()`,
`move_leader(target_id)`, `snapshot()`. `snapshot()` returns the snapshot blobs as a
`Array[SnapshotResponse]`; the transport collects the stream, so a large snapshot is
held in memory.

### Lock and Election — `client.lock()` / `client.election()`

`lock(name, lease)`, `unlock(key)`, and `campaign(name, value, lease)`,
`proclaim(leader, value)`, `leader(name)`, `resign(leader)`.

## Concurrency helpers

`moonbitstack/moonetcd/concurrency` wraps the lease-backed patterns from clientv3.

```moonbit
import {
  "moonbitstack/moonetcd/client",
  "moonbitstack/moonetcd/concurrency",
}

let session = @concurrency.Session::new(client, 30L)   // grants a lease
let mutex = @concurrency.Mutex::new(client, session, b"/my-lock")
mutex.lock()
// critical section
mutex.unlock()
session.close()                                         // revokes the lease
```

- `Session` grants a lease and revokes it on `close`; both are plain unary calls. For a
  long-lived session, open `session.keep_alive(task_group)` and drive the returned
  `KeepAlive` so the lease does not expire.
- `Mutex` is a distributed lock over `v3lock`, held on the session's lease, so it is
  released automatically if the holder dies.
- `Election` campaigns, proclaims, and resigns over `v3election`.

## Errors

Every client method raises `EtcdError`:

- `Refused(Status)` — a non-OK gRPC status, carrying the code and message.
- `Compacted(revision)` — the requested revision was compacted (etcd's
  `FAILED_PRECONDITION`).
- `FutureRev(revision)` — the requested revision is in the future (etcd's
  `OUT_OF_RANGE`).

`EtcdError::message()` renders a human-readable string. Match on the variant to react
to compaction or a future revision without scraping text.

## Connection

`ClientConfig` (`@moonetcd.default_client_config` is the preset) holds:

| Field | Meaning |
| --- | --- |
| `endpoints` | `Array[String]` of `"host:port"`; a missing port defaults to 2379. |
| `username`, `password` | etcd credentials; authentication happens at connect. |
| `token` | a pre-existing auth token to reuse. |
| `dial_timeout_millis` | connection timeout. |
| `keep_alive_millis` | HTTP/2 keep-alive interval. |
| `tls` | TLS settings (see the note below). |

Multiple endpoints are load-balanced and failed over by the underlying channel. A
Watch or KeepAlive reconnects to the next endpoint if its connection drops.

## Examples

Each example is a runnable `moon run` target. They expect etcd at
`127.0.0.1:2379` (etcd's default client URL); start one first, or point the
`endpoint` in the example at your member.

```sh
moon run --target native src/examples/00-connect   # dial and print member status
moon run --target native src/examples/01-kv        # put / get / prefix scan / delete
moon run --target native src/examples/03-lease     # grant a lease, attach a key, revoke
moon run --target native src/examples/04-txn       # compare-and-swap with a transaction
moon run --target native src/examples/05-lock      # distributed mutex over a session
```

Watch is exercised by the integration tests (`moon test --target native`) rather than a
`moon run` example: the `async fn main` runtime that `moon run` uses cannot drive the
background HTTP/2 read pump that a bidi Watch/KeepAlive needs, while the `async test`
runtime can. See the note under Notes.

## Building and testing

```sh
moon check --target all --deny-warn
moon build --target all
moon test  --target all
moon info  --target all
```

The protobuf codecs have network-free round-trip tests that run on every target. The
transport has an in-process test that drives the real HTTP/2 engine over a loopback
socket against a stand-in gRPC server, so the unary path is checked without an etcd
binary. The CI additionally starts a real etcd (single node and a three-node cluster)
and runs the examples against it.

## Notes

- The transport is h2c (HTTP/2 over plaintext) through `moonrpc`. The `TlsConfig`
  fields are present so callers can configure TLS, but they are honoured only once
  TLS reaches the transport.
- `Maintenance::snapshot()` buffers the whole stream; a very large snapshot is held in
  memory.
- Watch and Lease KeepAlive use a pull model (`next()` returns one response at a
  time). Open them inside `@async.with_task_group` so the connection's read pump runs.
- Runtime note: the bidi Watch/KeepAlive streams rely on a background HTTP/2 read pump
  (`@async.TaskGroup::spawn`). They run under the `async test` runtime and under a
  multi-threaded executor, but the single-threaded `async fn main` runtime that
  `moon run` uses does not schedule that pump reliably, so a `moon run` demo of Watch
  can stall. The integration tests run them for real against etcd, so use
  `moon test --target native` to exercise Watch/KeepAlive.

## License

Apache-2.0. See [LICENSE](LICENSE).
