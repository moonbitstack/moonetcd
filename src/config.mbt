// Client configuration. The record is pure data so it lives in the all-targets
// root; the native transport reads it when it dials. TLS is present so callers can
// set it today, but moonrpc's transport is h2c for now (see the delivery notes),
// so `tls.enabled` is honoured only once TLS reaches the transport.

///|
/// TLS settings for a connection. `enabled` is honoured by the client only once the
/// transport carries TLS; the record is present so callers can configure it now.
#derive(Eq)
pub(all) struct TlsConfig {
  enabled : Bool
  ca_cert : Bytes
  cert : Bytes
  key : Bytes
  server_name : String
}

///|
pub extend TlsConfig with Eq::{not_equal, equal}

///|
pub let default_tls : TlsConfig = {
  enabled: false,
  ca_cert: b"",
  cert: b"",
  key: b"",
  server_name: "",
}

///|
/// How a client reaches etcd: the endpoints to dial, the credentials to
/// authenticate with, timeouts, and TLS. Only `endpoints` is required; everything
/// else has a safe default.
#derive(Eq)
pub(all) struct ClientConfig {
  endpoints : Array[String]
  username : String
  password : String
  token : String
  dial_timeout_millis : Int32
  keep_alive_millis : Int32
  tls : TlsConfig
}

///|
pub extend ClientConfig with Eq::{not_equal, equal}

///|
/// The preset every `connect` falls back to: a five-second dial timeout, no auth,
/// no TLS.
pub let default_client_config : ClientConfig = {
  endpoints: [],
  username: "",
  password: "",
  token: "",
  dial_timeout_millis: 5000,
  keep_alive_millis: 0,
  tls: default_tls,
}
