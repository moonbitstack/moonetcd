// The message table of the HTTP/JSON gateway: one lookup that finds a message's
// fields by its name, over the two files that hold them. A name that is not here is
// a call the gateway cannot frame, which the transport reports rather than guesses.

///|
/// The fields of the named message, in wire order.
fn gateway_fields(name : String) -> Array[JsonField] raise EtcdError {
  if kv_message_fields(name) is Some(fields) {
    return fields
  }
  if admin_message_fields(name) is Some(fields) {
    return fields
  }
  raise gateway_error(13, "gateway: no such message: " + name)
}
