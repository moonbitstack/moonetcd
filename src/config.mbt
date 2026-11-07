// Client configuration. The record is pure data so it lives in the all-targets
// root; the native transports read it when they dial.

///|
/// TLS settings for a connection. With `enabled` the transports dial TLS: `ca_cert` is
/// what they trust, `cert` and `key` are the client's own certificate for a member that
/// asks for one, and `server_name` is the name the member's certificate has to carry.
///
/// Empty `ca_cert` means the public roots. Empty `server_name` means the endpoint's own
/// host, which is what a certificate issued for the address it is reached by says.
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
/// The preset: no TLS.
pub let default_tls : TlsConfig = {
  enabled: false,
  ca_cert: b"",
  cert: b"",
  key: b"",
  server_name: "",
}

///|
/// How a client reaches etcd: the endpoints to dial, the credentials to authenticate
/// with, timeouts, and TLS. Only `endpoints` is required; everything else has a safe
/// default.
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
/// The preset every `connect` falls back to: a five-second dial timeout, no auth, no TLS.
pub let default_client_config : ClientConfig = {
  endpoints: [],
  username: "",
  password: "",
  token: "",
  dial_timeout_millis: 5000,
  keep_alive_millis: 0,
  tls: default_tls,
}
