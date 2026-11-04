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
