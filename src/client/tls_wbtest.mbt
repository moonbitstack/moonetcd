// TLS as the two transports dial it, against servers this file starts on a loopback port
// the system chose. The certificates in `fixtures_wbtest.mbt` say which way each case has
// to go: one root signed all of them, one server certificate names `localhost` by address
// and by DNS, another by DNS alone.

///|
/// A gRPC server that answers `Range` with what its request named, and the TLS setup it
/// listens with. The caller runs `serve` on a task of its own and cancels it.
fn tls_grpc_server(
  cert : String,
  client_auth? : @tls.ClientAuth,
) -> (@net.GrpcServer, @tls.Server) raise {
  let server = @net.GrpcServer::new()
  server.register("/etcdserverpb.KV/Range", req => {
    match (Some(@moonetcd.RangeRequest::decode(req)) catch { _ => None }) {
      Some(rr) =>
        @moonetcd.RangeResponse::{
          header: @moonetcd.ResponseHeader::{
            ..@moonetcd.ResponseHeader::empty(),
            revision: 7L,
          },
          kvs: [
            @moonetcd.KeyValue::{
              ..@moonetcd.KeyValue::empty(),
              key: rr.key,
              value: b"secure",
              mod_revision: 7L,
            },
          ],
          more: false,
          count: 1L,
        }.encode()
      None => b""
    }
  })
  let serving = @tls.Server::new(
    [@x509.pem(cert)],
    @x509.PrivateKey::pem(server_key),
    alpn=[@net.alpn_h2],
    client_auth?,
  )
  (server, serving)
}

///|
/// A client configuration that trusts `ca` and, when given, presents `cert` and `key`.
fn secure_config(
  port : Int32,
  ca : String,
  server_name~ : String = "",
  cert~ : String = "",
  key~ : String = "",
) -> @moonetcd.ClientConfig {
  @moonetcd.ClientConfig::{
    ..@moonetcd.default_client_config,
    endpoints: ["127.0.0.1:\{port}"],
    tls: @moonetcd.TlsConfig::{
      enabled: true,
      ca_cert: @utf8.encode(ca),
      cert: @utf8.encode(cert),
      key: @utf8.encode(key),
      server_name,
    },
  }
}

///|
async test "tls: a gRPC call reaches a member whose certificate the configured CA signed" {
  @async.with_task_group <| g => {
    let (server, serving) = tls_grpc_server(server_cert)
    let running = g.spawn(() => server.serve(port=0, tls=serving))
    let port = bound_port(server)
    let client = Client::connect(secure_config(port, root))
    let response = client.kv().get(b"secure/key")
    assert_eq(response.header.revision, 7L)
    assert_eq(response.kvs[0].value, b"secure")
    client.close()
    running.cancel()
  }
}

///|
async test "tls: a certificate that does not name the address dialled is refused" {
  @async.with_task_group <| g => {
    // This certificate names `localhost` and no address, and no name was configured to
    // check it against, so the handshake has nothing to verify it with.
    let (server, serving) = tls_grpc_server(named_cert)
    let running = g.spawn(() => server.serve(port=0, tls=serving))
    let port = bound_port(server)
    let client = Client::connect(secure_config(port, root))
    let refused = try {
      ignore(client.kv().get(b"secure/key"))
      false
    } catch {
      _ => true
    }
    assert_true(refused)
    client.close()
    running.cancel()
  }
}

///|
async test "tls: server_name verifies a member reached by address" {
  @async.with_task_group <| g => {
    let (server, serving) = tls_grpc_server(named_cert)
    let running = g.spawn(() => server.serve(port=0, tls=serving))
    let port = bound_port(server)
    let client = Client::connect(
      secure_config(port, root, server_name="localhost"),
    )
    let response = client.kv().get(b"secure/key")
    assert_eq(response.kvs[0].value, b"secure")
    client.close()
    running.cancel()
  }
}

///|
async test "tls: a member whose certificate another CA signed is refused" {
  @async.with_task_group <| g => {
    let (server, serving) = tls_grpc_server(server_cert)
    let running = g.spawn(() => server.serve(port=0, tls=serving))
    let port = bound_port(server)
    let client = Client::connect(secure_config(port, other_root))
    let refused = try {
      ignore(client.kv().get(b"secure/key"))
      false
    } catch {
      _ => true
    }
    assert_true(refused)
    client.close()
    running.cancel()
  }
}

///|
async test "tls: a member that asks for a client certificate gets one" {
  @async.with_task_group <| g => {
    let anchors = @x509.Roots::pem(root) catch {
      _ => fail("the test root does not parse")
    }
    let wanted = @tls.ClientAuth::new(mode=@tls.Required, roots=anchors)
    let (server, serving) = tls_grpc_server(server_cert, client_auth=wanted)
    let running = g.spawn(() => server.serve(port=0, tls=serving))
    let port = bound_port(server)
    let bare = Client::connect(secure_config(port, root))
    let refused = try {
      ignore(bare.kv().get(b"secure/key"))
      false
    } catch {
      _ => true
    }
    assert_true(refused)
    bare.close()
    let client = Client::connect(
      secure_config(port, root, cert=client_cert, key=client_key),
    )
    assert_eq(client.kv().get(b"secure/key").kvs[0].value, b"secure")
    client.close()
    running.cancel()
  }
}

///|
/// Answer one gateway `Range` request with a fixed JSON body, then hang up.
async fn serve_gateway_range(conn : @tcp.Conn) -> Unit {
  let head = conn.read_until("\r\n\r\n") catch { _ => None }
  match head {
    None => conn.close()
    Some(head) => {
      let wanted = content_length(head)
      if wanted > 0 {
        let _ = conn.read_exactly(wanted) catch { _ => b"" }
      }
      let body =
        #|{"header":{"cluster_id":"1","member_id":"2","revision":"9","raft_term":"1"},"kvs":[{"key":"c2VjdXJlL2tleQ==","create_revision":"9","mod_revision":"9","version":"1","value":"c2VjdXJl"}],"count":"1"}
      let reply = "HTTP/1.1 200 OK\r\ncontent-type: application/json\r\ncontent-length: " +
        body.length().to_string() +
        "\r\n\r\n" +
        body
      conn.write(reply)
      conn.shutdown() catch {
        _ => ()
      }
    }
  }
}

///|
/// Serve `count` gateway requests, one connection each. A client the certificate check
/// turns away fails its handshake, so that attempt is skipped rather than served.
async fn serve_gateway(listener : @tcp.Listener, count : Int32) -> Unit {
  let mut served = 0
  while served < count {
    let (conn, _) = listener.accept() catch { _ => continue }
    serve_gateway_range(conn)
    served = served + 1
  }
}

///|
/// An HTTP/1.1 server over TLS with `cert`, on a port the system chose. It names `h2` and
/// nothing else, as etcd's own listener does: a client that offers `http/1.1` is refused
/// (RFC 7301 §3.2), and one that offers no protocol at all is served HTTP/1.1.
async fn tls_gateway_server(cert : String) -> (@tcp.Listener, Int32) {
  let serving = @tls.Server::new(
    [@x509.pem(cert)],
    @x509.PrivateKey::pem(server_key),
    alpn=[@net.alpn_h2],
  )
  let listener = @tcp.listen(host="127.0.0.1", port=0, tls=serving)
  (listener, listener.addr().port())
}

///|
async test "tls: the gateway reaches a member over TLS with HTTP/1.1" {
  @async.with_task_group <| g => {
    let (listener, port) = tls_gateway_server(server_cert)
    let running = g.spawn(() => serve_gateway(listener, 1))
    let client = Client::connect_gateway(secure_config(port, root))
    let response = client.kv().get(b"secure/key")
    assert_eq(response.header.revision, 9L)
    assert_eq(response.kvs[0].key, b"secure/key")
    assert_eq(response.kvs[0].value, b"secure")
    client.close()
    running.cancel()
    listener.close()
  }
}

///|
async test "tls: the gateway verifies a member by the name it was given" {
  @async.with_task_group <| g => {
    let (listener, port) = tls_gateway_server(named_cert)
    let running = g.spawn(() => serve_gateway(listener, 1))
    // The certificate names `localhost` alone: a client that dials the address and names
    // no host has nothing the certificate answers to.
    let bare = Client::connect_gateway(secure_config(port, root))
    let refused = try {
      ignore(bare.kv().get(b"secure/key"))
      false
    } catch {
      _ => true
    }
    assert_true(refused)
    bare.close()
    let named = Client::connect_gateway(
      secure_config(port, root, server_name="localhost"),
    )
    assert_eq(named.kv().get(b"secure/key").kvs[0].value, b"secure")
    named.close()
    running.cancel()
    listener.close()
  }
}
