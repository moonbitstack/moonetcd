// What a handle needs from a transport, and what a transport needs from its streams.
// The typed handles (`KV`, `Lease`, `Watch`, …) are written against `Transport`, so
// the gRPC transport and the HTTP/JSON gateway transport are interchangeable — and a
// third one can be plugged in without touching a handle.
//
// A transport answers in the message wire form; decoding stays with the handle, so
// the two transports cannot disagree about what a reply means.

///|
/// One etcd endpoint reached one way: gRPC over HTTP/2, or etcd's HTTP/JSON gateway.
/// `connect` and `connect_gateway` build the two that ship; `Client::of_transport`
/// takes any implementation.
pub(open) trait Transport {
  ///|
  /// One request, one reply, both in wire form.
  async fn unary(
    Self,
    grpc_method : String,
    body : Bytes,
    metadata~ : Array[@header.Header],
    timeout? : Int32,
  ) -> Bytes raise EtcdError

  ///|
  /// One request and every reply it produces, for the server-streaming calls.
  async fn collect(
    Self,
    grpc_method : String,
    body : Bytes,
    metadata~ : Array[@header.Header],
  ) -> Array[Bytes] raise EtcdError

  ///|
  /// Open a watch and send its create request. The caller supplies the task group the
  /// stream's background work runs in.
  async fn watch(
    Self,
    create : WatchCreateRequest,
    metadata~ : Array[@header.Header],
    group~ : @async.TaskGroup[Unit],
  ) -> &WatchStream raise EtcdError

  ///|
  /// Open the lease keep-alive session.
  async fn keep_alive(
    Self,
    metadata~ : Array[@header.Header],
    group~ : @async.TaskGroup[Unit],
  ) -> &KeepAliveStream raise EtcdError

  ///|
  /// Drop every connection. Calls in flight are abandoned.
  fn close(Self) -> Unit
}

///|
/// A watch in progress: events arrive one at a time, and a stream that drops resumes
/// from the last revision it reported.
pub(open) trait WatchStream {
  ///|
  /// The next reply, or `None` once the watch has ended.
  async fn next(Self) -> WatchResponse? raise EtcdError

  ///|
  /// End the watch and release its connection.
  fn close(Self) -> Unit
}

///|
/// A lease keep-alive session: requests go out, acknowledgements come back.
pub(open) trait KeepAliveStream {
  ///|
  /// Ask the server to hold `id` for another period.
  async fn keep_alive(Self, id : Int64) -> Unit raise EtcdError

  ///|
  /// The next acknowledgement, or `None` once the session has ended.
  async fn next(Self) -> LeaseKeepAliveResponse? raise EtcdError

  ///|
  /// End the session and release its connection.
  fn close(Self) -> Unit
}

///|
/// gRPC's `UNAVAILABLE`: what a transport reports when a connection died under a call.
let unavailable : Int32 = 14

///|
/// The error a transport failure turns into: `UNAVAILABLE`, as gRPC maps it.
fn transport_error(what : String) -> EtcdError {
  @moonetcd.EtcdError::Refused(@moonetcd.Status::{
    code: unavailable,
    message: "transport error: " + what,
  })
}

///|
/// A reply that arrived but cannot be used as the call expects.
fn refused(code : Int32, message : String) -> EtcdError {
  @moonetcd.EtcdError::Refused(@moonetcd.Status::{ code, message, })
}
