# moonetcd

An etcd v3 client for MoonBit — the feature surface of etcd's official Go client
(`clientv3`), over either of the two transports etcd serves.

`moonetcd` speaks the etcd v3 API (`etcdserverpb`, `mvccpb`, `v3lock`, `v3election`)
over gRPC on HTTP/2 via [`moonrpc`](https://github.com/moonbitstack/moonrpc), or over
etcd's HTTP/JSON gateway, which every etcd serves on the same port, in the clear or over
TLS. It gives you the
whole client either way: key-value reads and writes, transactions, watches that
survive a dropped connection, leases and keep-alives, cluster and auth
administration, maintenance, and the client-side `concurrency` helpers (sessions,
mutexes, leader election).

## Layout

| Package | Contents |
| --- | --- |
| `moonbitstack/moonetcd` | Protobuf message types and codecs for the etcd v3 API, the JSON mapping the gateway speaks, key helpers and the error model. Pure data — builds on every target. |
| `moonbitstack/moonetcd/client` | Both transports — gRPC, and the HTTP/JSON gateway — under one set of handles: `Client`, `KV`, `Watch`, `Lease`, `Cluster`, `Auth`, `Maintenance`, `Lock`, `Election`. Native only. |
| `moonbitstack/moonetcd/concurrency` | `Session`, `Mutex`, `Election` built on the client. Native only. |
| `moonbitstack/moonetcd/sd` | The `moonsd` contract on etcd: `Registry`. Native only. |
| `moonbitstack/moonetcd/examples/...` | Runnable examples (see below). |

The root package carries no transport, so a program on any target can decode etcd
messages and frame them for the gateway; the transports and the concurrency helpers
open sockets and are native only.

## Install

```sh
moon add moonbitstack/moonetcd
```

## Quick start

```mbt native
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

The same program over etcd's HTTP/JSON gateway differs in one line:

```mbt native
let client = @client.Client::connect_gateway(@moonetcd.ClientConfig::{
  ..@moonetcd.default_client_config,
  endpoints: ["127.0.0.1:2379"],
})
```

## Two transports

etcd answers on one client port in two dialects. gRPC is the native one; the
HTTP/JSON gateway is a `POST` per call, with the same messages written as JSON:
field names exactly as the `.proto` spells them, keys and values in standard base64,
64-bit integers as decimal strings, and enumerations by name.

```sh
curl -s -X POST http://127.0.0.1:2379/v3/kv/range -d '{"key":"L2dyZWV0aW5n"}'
```

| | gRPC | HTTP/JSON gateway |
| --- | --- | --- |
| Built by | `Client::connect` | `Client::connect_gateway` |
| Handles | the same | the same |
| Bytes on the wire | protobuf | JSON |
| One port | 2379 | 2379 |
| Watch | one bidi stream per watch, resumed from the last revision | one streamed `POST` per watch, reissued from the last revision |
| Keep-alive | one bidi stream, many ids | one `POST` per tick, answered once |
| Failover | the channel balances; a stream moves to the next member | the next call dials the next member |

Pick the gateway when something in the path already speaks HTTP and not gRPC — a
proxy, a language without an HTTP/2 client, a shell script. Both transports raise
the same `EtcdError` values at the same places; the messages a handle decodes are
the same structs, so a program can switch by changing the constructor and nothing
else.

Two gateway differences worth knowing:

- A watch is cancelled by closing its stream, which is how the gateway ends it.
- A keep-alive is one request and one acknowledgement, so `KeepAlive::next()`
  returns what the last `keep_alive(id)` was told rather than a stream of
  autonomous renewals.

A third transport can be plugged in: implement the `Transport` trait (one unary
call, one server-streaming call, a watch and a keep-alive session, and `close`) and
hand it to `Client::of_transport`. The handles are written against that trait and
change nowhere else.

## TLS

Both transports dial TLS when the configuration asks for it. `ca_cert` is what the member's
certificate has to chain to — a PEM bundle, one DER certificate, or empty for the public roots;
`cert` and `key` are the client's own certificate and key, for a member that asks for one;
`server_name` is the name its certificate has to carry, the endpoint's own host when empty.

```mbt native
async fn secure(config : @moonetcd.ClientConfig, ca : Bytes) -> @client.Client {
  @client.Client::connect({
    ..config,
    tls: @moonetcd.TlsConfig::{ ..@moonetcd.default_tls, enabled: true, ca_cert: ca },
  })
}
```

The same fields go to `Client::connect_gateway`; nothing else about the client changes.

The two transports speak different protocols on that one port, and the handshake is what tells
them apart: gRPC names `h2` and refuses a connection that settled on anything else, while the
gateway names no protocol at all — etcd's TLS listener offers `h2` alone, so a client that
offers `http/1.1` is turned away (RFC 7301 §3.2) and one that offers nothing is served
HTTP/1.1. Both of those are the library's business, not the caller's.

`server_name` is what the member's certificate is judged against, on both transports; the
handshake names the endpoint that was dialled, so a member reached by address and certified by
name is verified by the name and dialled by the address. A certificate, an anchor or a key that
does not parse is refused at `connect` with `UNAUTHENTICATED` rather than at the first call.

A member started with `--client-cert-auth` reaches its own gateway through the server
certificate, so that certificate needs to be valid for client authentication too, or the
gateway half of a mutual-TLS member answers with a handshake failure.

`@client.grpc_tls` and `@client.gateway_tls` build those two handshakes for a caller plugging
its own transport into `Client::of_transport`.

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
and the four `min`/`max` revision bounds.

### Watch — `client.watch()`

`watch_create(task_group, WatchCreateRequest)` opens a bidi stream on its own
multiplexed channel and returns a `WatchChan`. `WatchChan::next()` blocks until the
next `WatchResponse` (or `None` once cancelled). If the stream drops — a failed
member, a network blip — it reconnects to the next configured endpoint and re-issues
the create with `start_revision` set just past the last event it saw, so no event is
lost. A `WatchResponse` with a non-zero `compact_revision` means the requested
revision was compacted; check it on the response.

```mbt native
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

## Service discovery

`moonetcd/sd` implements the `moonsd` contract on etcd. An endpoint is a key on a lease, so it goes when the lease does, and a watcher follows etcd's revisions. A watch that compaction or a dropped connection ends costs one more read.

```mbt native
async fn announced(client : @client.Client, group : @async.TaskGroup[Unit]) -> Unit {
  let registry = @sd.Registry::new(client)
  group.spawn_bg(() => @moonsd.hold(registry, "greeter", @moonsd.Endpoint::new("10.0.0.1", 12000)))
  let endpoints = registry.resolve("greeter")
  println("\{endpoints.length()} instance(s)")
}
```

`Registry::new` takes `prefix`, default `/moonsd`. A lease lasts whole seconds, and the server sets a minimum, so a short `ttl` is rounded up. Any number of tasks may share one registry and its client.

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
| `tls` | TLS settings: `enabled`, `ca_cert`, `cert`, `key`, `server_name`. |

Multiple endpoints are load-balanced and failed over by the underlying channel. When a member
dies under a call, a read goes again on the next member; a write answers `UNAVAILABLE`, since
it may have run, and the next call goes to a member that is up. A Watch reconnects to the next
endpoint and carries on from the revision after the last one it saw.

## Examples

Each example is a runnable `moon run` target. They expect etcd at
`127.0.0.1:2379` (etcd's default client URL); start one first, or point the
`endpoint` in the example at your member.

```sh
moon run --target native src/examples/00-connect   # dial and print member status
moon run --target native src/examples/01-kv        # put / get / prefix scan / delete
moon run --target native src/examples/02-watch     # watch a key and read the event
moon run --target native src/examples/03-lease     # grant a lease, attach a key, revoke
moon run --target native src/examples/04-txn       # compare-and-swap with a transaction
moon run --target native src/examples/05-lock      # distributed mutex over a session
moon run --target native src/examples/06-gateway   # the same calls over HTTP/JSON
```

## Building and testing

```sh
moon check --target all --deny-warn
moon build --target all
moon test  --target all
moon info  --target all
```

The protobuf codecs and the gateway's JSON mapping have network-free round-trip tests that run on
every target, and `scripts/check_field_numbers.py` compares every field number and every gateway
field name with etcd's own `.proto` files, which a round trip cannot do. The gRPC transport has an
in-process test that drives the real HTTP/2 engine over a loopback socket against a stand-in gRPC
server.

`src/integration` runs against a real etcd: leases lapsing, locks and elections changing hands,
compaction, roles and tokens, a snapshot, and many tasks sharing one client. The same cases run
over gRPC and over the gateway, and every answer has to come back the same; a watch that keeps
delivering while the stream is open, a lease id past 2^53, and a token in the `Authorization`
header are checked on the gateway alone. `scripts/etcd_cluster.sh`
starts three members, and with `MOONETCD_MEMBERS` naming it the suite kills one under a watch and
under plain calls. Without a server the tests return early; with `MOONETCD_LIVE` set, as in CI,
a missing server fails them.

The same suite runs over TLS, and the whole of it — both transports — is what the certificates
have to let through. `scripts/etcd_tls.sh` starts a member with a certificate the suite is
given; `MOONETCD_ENDPOINT` moves the suite to it, and `MOONETCD_CA` is the anchor that signed
it. `MOONETCD_CERT` and `MOONETCD_KEY` add a client certificate for every call, `MOONETCD_SERVER_NAME`
names what the certificate has to carry, and a member that asks for a client certificate is
reached through `MOONETCD_MTLS_ENDPOINT`, `MOONETCD_MTLS_CERT` and `MOONETCD_MTLS_KEY`.

```sh
bash scripts/etcd_tls.sh up /tmp/etcd-tls 23379
bash scripts/etcd_tls.sh up /tmp/etcd-mtls 23380 --client-cert-auth --certs /tmp/etcd-tls/certs
MOONETCD_LIVE=1 MOONETCD_ENDPOINT=127.0.0.1:23379 MOONETCD_CA=/tmp/etcd-tls/certs/ca.crt \
  MOONETCD_MTLS_ENDPOINT=127.0.0.1:23380 \
  MOONETCD_MTLS_CERT=/tmp/etcd-tls/certs/client.crt \
  MOONETCD_MTLS_KEY=/tmp/etcd-tls/certs/client.key \
  moon test --target native
```

The loopback tests bring their own certificates, written by `scripts/gen_certs.py` into
`src/client/fixtures_wbtest.mbt`: a root, two server certificates under it that differ in what
they name, and a client certificate. They start a gRPC server and an HTTP/1.1 one on a port the
system chose, so the suite can run side by side with itself.

## Notes

- TLS is off unless `TlsConfig::enabled` is set, and then both transports dial it.
- `Maintenance::snapshot()` buffers the whole stream; a very large snapshot is held in
  memory.
- Watch and Lease KeepAlive use a pull model (`next()` returns one response at a
  time). Open them inside `@async.with_task_group` so the connection's read pump runs.
- The gateway transport keeps its unary connections for reuse and dials again when
  one has been closed under it; a stream owns its connection until it ends.

## License

Apache-2.0. See [LICENSE](LICENSE).
