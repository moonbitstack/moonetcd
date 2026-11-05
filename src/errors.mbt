// The error model. A plain gRPC failure surfaces as `Refused`; etcd's own two
// revision conditions carry the offending revision so callers can match them
// directly. The transport layer builds these from a gRPC `StatusError`.

///|
/// A gRPC status: the numeric code (one of the 17 gRPC codes) and the server's
/// message. Surfaces when a call ends other than OK.
#derive(Eq)
pub(all) struct Status {
  code : Int32
  message : String
}

///|
pub extend Status with Eq::{not_equal, equal}

///|
/// The message that comes with a `Compacted` or `FutureRev` error: the revision
/// the server rejected.
pub fn Status::to_string(self : Status) -> String {
  "rpc error: code = " + self.code.to_string() + " desc = " + self.message
}

///|
/// The error type every client method raises. A plain gRPC failure is `Refused`;
/// etcd's revision conditions (`Compacted`, `FutureRev`) carry the revision so a
/// caller can react without scraping a string.
pub(all) suberror EtcdError {
  Refused(Status)
  Compacted(Int64)
  FutureRev(Int64)
}

///|
pub impl Show for EtcdError with fn output(self, logger) {
  logger.write_string(self.message())
}

///|
pub extend EtcdError with Show::{to_string, output}

///|
/// The error a failed call ended with, from the status its transport reported. Both
/// revision conditions are sent as `OUT_OF_RANGE` over gRPC and as `UNKNOWN` by the
/// lock and election services, so they are told apart by the message text — the way
/// etcd's own client does — rather than by the code.
pub fn EtcdError::of(code : Int32, message : String) -> EtcdError {
  if message.contains("required revision has been compacted") {
    return Compacted(extract_rev(message))
  }
  if message.contains("required revision is a future revision") {
    return FutureRev(extract_rev(message))
  }
  Refused(Status::{ code, message, })
}

///|
/// The trailing decimal integer of an etcd error message, such as the revision in
/// `etcdserver: mvcc: required revision has been compacted: 12345`.
fn extract_rev(message : String) -> Int64 {
  let chars = message.to_array()
  let n = chars.length()
  let mut end = -1
  let mut i = n - 1
  while i >= 0 {
    let digit = chars[i].to_int()
    if digit >= 48 && digit <= 57 {
      end = i + 1
      break
    }
    i = i - 1
  }
  if end < 0 {
    return 0L
  }
  let mut start = end - 1
  while start >= 0 && chars[start].to_int() >= 48 && chars[start].to_int() <= 57 {
    start = start - 1
  }
  let mut value : Int64 = 0L
  let mut k = start + 1
  while k < end {
    value = value * 10L + Int64::from_int(chars[k].to_int() - 48)
    k = k + 1
  }
  value
}

///|
pub fn EtcdError::message(self : EtcdError) -> String {
  match self {
    Refused(s) => s.to_string()
    Compacted(rev) =>
      "etcdserver: mvcc: required revision has been compacted: " +
      rev.to_string()
    FutureRev(rev) =>
      "etcdserver: mvcc: required revision is a future revision: " +
      rev.to_string()
  }
}
