// A member that asks for a client certificate. `MOONETCD_MTLS_ENDPOINT` names it,
// `MOONETCD_MTLS_CERT` and `MOONETCD_MTLS_KEY` are the certificate to present, and
// `MOONETCD_CA` is the anchor that signed it. Without the endpoint the case returns.

///|
/// A configuration for the member that asks for a certificate, presenting one or not.
async fn mtls_config(present : Bool) -> @moonetcd.ClientConfig? {
  guard @env.get_env_var("MOONETCD_MTLS_ENDPOINT") is Some(endpoint) else {
    return None
  }
  let cert = if present { live_file("MOONETCD_MTLS_CERT") } else { b"" }
  let key = if present { live_file("MOONETCD_MTLS_KEY") } else { b"" }
  Some({
    ..@moonetcd.default_client_config,
    endpoints: [endpoint],
    tls: @moonetcd.TlsConfig::{
      enabled: true,
      ca_cert: live_file("MOONETCD_CA"),
      cert,
      key,
      server_name: @env.get_env_var("MOONETCD_SERVER_NAME").unwrap_or(""),
    },
  })
}

///|
async test "mutual tls: a member that asks for a client certificate lets in only one" {
  guard mtls_config(false) is Some(without) else { return }
  guard mtls_config(true) is Some(with_cert) else { return }
  let bare = @client.Client::connect(without)
  let refused = try {
    ignore(bare.maintenance().status())
    false
  } catch {
    _ => true
  }
  assert_true(refused)
  bare.close()
  let client = @client.Client::connect(with_cert)
  let _ = client.kv().put(b"/moonetcd-mtls/grpc", b"v")
  assert_eq(client.kv().get(b"/moonetcd-mtls/grpc").kvs[0].value, b"v")
  // The gateway dials the same certificate: the handshake is one TLS layer under either
  // transport, and a member that asks for a client certificate asks either way.
  let gateway = @client.Client::connect_gateway(with_cert)
  assert_eq(gateway.kv().get(b"/moonetcd-mtls/grpc").kvs[0].value, b"v")
  ignore(
    gateway
    .kv()
    .delete_range(@moonetcd.DeleteRangeRequest::{
      ..@moonetcd.DeleteRangeRequest::empty(),
      key: b"/moonetcd-mtls/grpc",
    }),
  )
  gateway.close()
  client.close()
}
