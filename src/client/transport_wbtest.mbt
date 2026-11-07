// The client transport, exercised end to end against an in-process gRPC server — no
// etcd needed. This drives the real H2 engine over a real TCP loopback socket, so it
// checks framing, the method path, request encoding, reply decoding and the unary
// `CallReply` path in one go. A handler stands in for the etcd server.

///|
/// The port a server is listening on, once `serve` has got that far.
async fn bound_port(server : @net.GrpcServer) -> Int32 {
  for _ in 0..<500 {
    match server.listener {
      Some(listener) => return listener.addr().port()
      None => @async.sleep(10)
    }
  }
  fail("the gRPC server never listened")
}

///|
/// Serve one KV method on a loopback port and drive the client against it. The
/// handlers decode the request with the same codecs the client encodes with, and echo
/// back a response the client decodes — a full round trip through both codecs.
async test "transport: KV Put and Range round-trip through a loopback gRPC server" {
  @async.with_task_group <| g => {
    let server = @net.GrpcServer::new()
    server.register("/etcdserverpb.KV/Put", req => {
      match (Some(@moonetcd.PutRequest::decode(req)) catch { _ => None }) {
        Some(pr) =>
          @moonetcd.PutResponse::{
            header: @moonetcd.ResponseHeader::empty(),
            prev_kv: @moonetcd.KeyValue::{
              ..@moonetcd.KeyValue::empty(),
              key: pr.key,
              value: pr.value,
              mod_revision: 42L,
            },
          }.encode()
        None => b""
      }
    })
    server.register("/etcdserverpb.KV/Range", req => {
      match (Some(@moonetcd.RangeRequest::decode(req)) catch { _ => None }) {
        Some(rr) =>
          @moonetcd.RangeResponse::{
            header: @moonetcd.ResponseHeader::{
              ..@moonetcd.ResponseHeader::empty(),
              revision: 42L,
            },
            kvs: [
              @moonetcd.KeyValue::{
                ..@moonetcd.KeyValue::empty(),
                key: rr.key,
                value: b"stored",
                mod_revision: 42L,
              },
            ],
            more: false,
            count: 1L,
          }.encode()
        None => b""
      }
    })
    let serve = g.spawn(() => server.serve(port=0))
    let port = bound_port(server)
    let cfg = @moonetcd.ClientConfig::{
      ..@moonetcd.default_client_config,
      endpoints: ["127.0.0.1:\{port}"],
    }
    let client = Client::connect(cfg)
    let put = client.kv().put(b"greeting", b"hello", prev_kv=true)
    assert_eq(put.prev_kv.key, b"greeting")
    assert_eq(put.prev_kv.value, b"hello")
    assert_eq(put.prev_kv.mod_revision, 42L)
    let got = client.kv().get(b"greeting")
    assert_eq(got.count, 1L)
    assert_eq(got.kvs.length(), 1)
    assert_eq(got.kvs[0].value, b"stored")
    client.close()
    serve.cancel()
  }
}
