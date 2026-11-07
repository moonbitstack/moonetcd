// Where the suite dials, and with what. One member by default; `MOONETCD_ENDPOINT` moves
// it, and the TLS variables let the same cases run against a member that speaks TLS —
// `MOONETCD_CA` for the anchors, `MOONETCD_CERT` and `MOONETCD_KEY` for a client
// certificate, `MOONETCD_SERVER_NAME` for the name its certificate has to carry.

///|
/// The endpoints this run dials.
fn live_endpoints() -> Array[String] {
  [@env.get_env_var("MOONETCD_ENDPOINT").unwrap_or("127.0.0.1:2379")]
}

///|
/// The bytes of a file the environment named, or empty when it named none. A path that
/// cannot be read is a broken configuration rather than a missing one: the run says so.
async fn live_file(name : String) -> Bytes {
  match @env.get_env_var(name) {
    None => b""
    Some(path) => {
      let data = @fs.read_file(path) catch {
        _ => fail("\{name} names \"" + path + "\", which cannot be read")
      }
      data.binary()
    }
  }
}

///|
/// The TLS settings the environment describes, or none when it names no certificates.
async fn live_tls() -> @moonetcd.TlsConfig {
  let ca = live_file("MOONETCD_CA")
  let cert = live_file("MOONETCD_CERT")
  let key = live_file("MOONETCD_KEY")
  if ca.length() == 0 && cert.length() == 0 && key.length() == 0 {
    return @moonetcd.default_tls
  }
  {
    enabled: true,
    ca_cert: ca,
    cert,
    key,
    server_name: @env.get_env_var("MOONETCD_SERVER_NAME").unwrap_or(""),
  }
}

///|
/// A configuration for this run's member, TLS included when the environment asks for it.
async fn live_config() -> @moonetcd.ClientConfig {
  {
    ..@moonetcd.default_client_config,
    endpoints: live_endpoints(),
    tls: live_tls(),
  }
}

///|
/// Whether the run promised that a member is up: with `MOONETCD_LIVE` set, as in CI, a
/// member that cannot be reached fails the case instead of skipping it.
fn live_required() -> Bool {
  @env.get_env_var("MOONETCD_LIVE") is Some(_)
}

///|
/// What to say when nothing answered.
fn live_missing() -> String {
  let endpoints = live_endpoints().join(", ")
  "no etcd at " + endpoints
}
