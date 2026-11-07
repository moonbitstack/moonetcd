// TLS for the two transports. etcd serves both dialects on one secure port and tells
// them apart by what the handshake settled on, so each transport names what it speaks:
// gRPC is HTTP/2 and names `h2`, and moonrpc refuses a connection that agreed to
// anything else. The gateway is HTTP/1.1 — and etcd's listener offers `h2` alone, which
// makes a client that offers `http/1.1` a refused handshake (RFC 7301 §3.2), while a
// client that offers no protocol at all is served HTTP/1.1. So the gateway offers none.

///|
/// A byte string that starts like a PEM file, rather than holding one DER certificate.
fn is_pem(data : Bytes) -> Bool {
  let head = if data.length() < 64 { data.length() } else { 64 }
  @utf8.decode_lossy(data[:head]).contains("-----BEGIN")
}

///|
/// The trust anchors a TLS configuration names: its `ca_cert` when it carries any, the
/// public roots otherwise. A `ca.crt` is either a PEM bundle or a single DER
/// certificate, and both are accepted.
fn tls_roots(ca_cert : Bytes) -> @x509.Roots raise EtcdError {
  if ca_cert.length() == 0 {
    return @roots.mozilla()
  }
  if is_pem(ca_cert) {
    @x509.Roots::pem(@utf8.decode_lossy(ca_cert[:])) catch {
      _ => raise tls_error("the CA certificates do not parse as PEM")
    }
  } else {
    @x509.Roots::new(certs=[ca_cert]) catch {
      _ => raise tls_error("the CA certificate does not parse as DER")
    }
  }
}

///|
/// A client certificate chain in PEM form, leaf first, as a server is shown it.
fn tls_chain(cert : Bytes) -> Array[Bytes] raise EtcdError {
  guard cert.length() > 0 else { return [] }
  @x509.pems(@utf8.decode_lossy(cert[:])) catch {
    _ => raise tls_error("the client certificate does not parse as PEM")
  }
}

///|
/// The private key that goes with a client certificate.
fn tls_key(key : Bytes) -> @x509.PrivateKey raise EtcdError {
  @x509.PrivateKey::pem(@utf8.decode_lossy(key[:])) catch {
    _ => raise tls_error("the client key does not parse as PEM")
  }
}

///|
/// The error a TLS setting that cannot be used turns into: gRPC's `UNAUTHENTICATED`,
/// the code a peer refusing a certificate reports on the wire.
fn tls_error(message : String) -> EtcdError {
  refused(16, "tls: " + message)
}

///|
/// Judge the server's chain against the roots, by the name the caller configured rather
/// than the address that was dialled. The handshake hands a judge the host it dialled,
/// so a member reached by address and named by a certificate is verified here.
fn naming_judge(roots : @x509.Roots, name : String) -> @tls.Verify {
  @tls.Custom((chain, _host) => {
    let _ = @x509.verify(
      chain[:],
      roots,
      now=(@env.now() / 1000).reinterpret_as_int64(),
      host=name,
    )
  })
}

///|
/// Build the TLS client both transports dial with: `None` when TLS is switched off.
fn tls_client(
  tls_config : @moonetcd.TlsConfig,
  alpn~ : Array[String],
) -> @tls.Client? raise EtcdError {
  guard tls_config.enabled else { return None }
  let roots = tls_roots(tls_config.ca_cert)
  if (tls_config.cert.length() > 0) != (tls_config.key.length() > 0) {
    raise tls_error("a client certificate and its key go together")
  }
  let verify = if tls_config.server_name == "" {
    @tls.Chain
  } else {
    naming_judge(roots, tls_config.server_name)
  }
  let cert_key = if tls_config.key.length() > 0 {
    Some(tls_key(tls_config.key))
  } else {
    None
  }
  Some(
    @tls.Client::new(
      roots,
      alpn~,
      verify~,
      cert=tls_chain(tls_config.cert),
      cert_key?,
    ),
  )
}

///|
/// The TLS setup for the gRPC port: HTTP/2, so the client names `h2` and nothing else.
/// `None` when the configuration has TLS switched off.
pub fn grpc_tls(
  tls_config : @moonetcd.TlsConfig,
) -> @tls.Client? raise EtcdError {
  tls_client(tls_config, alpn=[@net.alpn_h2])
}

///|
/// The TLS setup for the gateway port: no protocol in ALPN, which is what leaves etcd
/// serving HTTP/1.1 rather than the HTTP/2 it offers. `None` when TLS is switched off.
pub fn gateway_tls(
  tls_config : @moonetcd.TlsConfig,
) -> @tls.Client? raise EtcdError {
  tls_client(tls_config, alpn=[])
}
