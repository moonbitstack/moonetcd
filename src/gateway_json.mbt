// etcd serves the same messages over a second transport: its HTTP/JSON gateway,
// where a message is a JSON object named the way the .proto names its fields, with
// 64-bit integers as decimal strings, `bytes` as standard base64, and enumerations
// by name (https://protobuf.dev/programming-guides/json/). The tables in
// `gateway_fields*.mbt` describe each message once; this file walks the protobuf
// wire form with them in either direction, so requests and replies share one
// description and neither can drift from the other.

///|
/// How a field appears in the gateway's JSON, which is also how to read it off the
/// wire: a scalar maps to a JSON type, a message to its own name, an enumeration to
/// its names indexed by number.
priv enum FieldKind {
  Str
  Bytes
  Bool
  Int64
  UInt32
  UInt64
  Enum(Array[String])
  Message(String)
  Rep(FieldKind)
}

///|
/// One field of a message: the number it carries on the wire and the name it
/// carries in the JSON. `presence` marks the arms of a oneof, which are written
/// even when they hold the default value — otherwise the arm would not be selected.
priv struct JsonField {
  number : Int32
  name : String
  kind : FieldKind
  presence : Bool
}

///|
/// A body the gateway cannot frame. The code is the one the gateway would have
/// answered with for the same input: 3 for a request it cannot read, 13 for a reply
/// that does not decode.
fn gateway_error(code : Int32, message : String) -> EtcdError {
  EtcdError::Refused(Status::{ code, message, })
}

///|
/// The protobuf wire reader with its failures turned into gateway errors, so the
/// read side below raises one error type and says nothing about who broke the bytes.
priv struct WireReader {
  inner : @proto.PbReader
}

///|
fn WireReader::new(bytes : Bytes) -> WireReader {
  { inner: @proto.PbReader::new(bytes), }
}

///|
fn WireReader::eof(self : WireReader) -> Bool {
  self.inner.eof()
}

///|
fn WireReader::tag(
  self : WireReader,
) -> (Int32, @proto.WireType) raise EtcdError {
  self.inner.read_tag() catch {
    _ => raise gateway_error(13, "gateway: the reply is not protobuf wire")
  }
}

///|
fn WireReader::skip(
  self : WireReader,
  wire : @proto.WireType,
) -> Unit raise EtcdError {
  self.inner.skip(wire) catch {
    _ => raise gateway_error(13, "gateway: the reply is not protobuf wire")
  }
}

///|
fn WireReader::string(self : WireReader) -> String raise EtcdError {
  self.inner.read_string() catch {
    _ => raise gateway_error(13, "gateway: the reply is not protobuf wire")
  }
}

///|
fn WireReader::bytes(self : WireReader) -> Bytes raise EtcdError {
  self.inner.read_bytes() catch {
    _ => raise gateway_error(13, "gateway: the reply is not protobuf wire")
  }
}

///|
fn WireReader::block(self : WireReader) -> Bytes raise EtcdError {
  self.inner.read_len_delim() catch {
    _ => raise gateway_error(13, "gateway: the reply is not protobuf wire")
  }
}

///|
fn WireReader::flag(self : WireReader) -> Bool raise EtcdError {
  self.inner.read_bool() catch {
    _ => raise gateway_error(13, "gateway: the reply is not protobuf wire")
  }
}

///|
fn WireReader::int32(self : WireReader) -> Int32 raise EtcdError {
  self.inner.read_int32() catch {
    _ => raise gateway_error(13, "gateway: the reply is not protobuf wire")
  }
}

///|
fn WireReader::int64(self : WireReader) -> Int64 raise EtcdError {
  self.inner.read_int64() catch {
    _ => raise gateway_error(13, "gateway: the reply is not protobuf wire")
  }
}

///|
fn WireReader::uint32(self : WireReader) -> UInt32 raise EtcdError {
  self.inner.read_uint32() catch {
    _ => raise gateway_error(13, "gateway: the reply is not protobuf wire")
  }
}

///|
fn WireReader::uint64(self : WireReader) -> UInt64 raise EtcdError {
  self.inner.read_uint64() catch {
    _ => raise gateway_error(13, "gateway: the reply is not protobuf wire")
  }
}

///|
fn WireReader::varint(self : WireReader) -> UInt64 raise EtcdError {
  self.inner.read_varint() catch {
    _ => raise gateway_error(13, "gateway: the reply is not protobuf wire")
  }
}

///|
/// The field numbered `number`, if this message has one.
fn field_at(fields : Array[JsonField], number : Int32) -> JsonField? {
  for field in fields {
    if field.number == number {
      return Some(field)
    }
  }
  None
}

///|
/// One message in the gateway's JSON, from its protobuf wire form.
fn message_json(message : String, wire : Bytes) -> Json raise EtcdError {
  let fields = gateway_fields(message)
  let values : Map[String, Json] = Map([])
  let lists : Map[String, Array[Json]] = Map([])
  let reader = WireReader::new(wire)
  while !reader.eof() {
    let (number, wire_type) = reader.tag()
    match field_at(fields, number) {
      None => reader.skip(wire_type)
      Some(field) =>
        match field.kind {
          Rep(item) => {
            let items = match lists.get(field.name) {
              Some(items) => items
              None => {
                let items : Array[Json] = []
                lists.set(field.name, items)
                items
              }
            }
            append_values(item, reader, wire_type, items)
          }
          kind => values.set(field.name, read_value(kind, reader))
        }
    }
  }
  let object : Map[String, Json] = Map([])
  for field in fields {
    match values.get(field.name) {
      Some(value) => object.set(field.name, value)
      None =>
        match lists.get(field.name) {
          Some(items) =>
            if items.length() > 0 {
              object.set(field.name, Json::array(items))
            }
          None => ()
        }
    }
  }
  Json::object(object)
}

///|
/// Append the value of one repetition of a repeated field. A repeated scalar arrives
/// packed from a conforming encoder, and etcd's own are; an unpacked one is read too.
fn append_values(
  item : FieldKind,
  reader : WireReader,
  wire_type : @proto.WireType,
  items : Array[Json],
) -> Unit raise EtcdError {
  match wire_type {
    LengthDelim =>
      match item {
        Int64 | UInt32 | UInt64 | Bool | Enum(_) => {
          let packed = WireReader::new(reader.block())
          while !packed.eof() {
            items.push(read_packed(item, packed))
          }
        }
        _ => items.push(read_value(item, reader))
      }
    _ => items.push(read_value(item, reader))
  }
}

///|
/// One element of a packed repeated scalar.
fn read_packed(item : FieldKind, reader : WireReader) -> Json raise EtcdError {
  match item {
    Int64 => Json::string(reader.int64().to_string())
    UInt32 => Json::number(reader.uint32().to_double())
    UInt64 => Json::string(reader.uint64().to_string())
    Bool => Json::boolean(reader.varint() != 0UL)
    Enum(names) => Json::string(enum_name(names, reader.int32()))
    _ => raise gateway_error(13, "gateway: packed field is not a scalar")
  }
}

///|
/// One value of a field.
fn read_value(kind : FieldKind, reader : WireReader) -> Json raise EtcdError {
  match kind {
    Str => Json::string(reader.string())
    Bytes => Json::string(@base64.encode(reader.bytes()[:]))
    Bool => Json::boolean(reader.flag())
    Int64 => Json::string(reader.int64().to_string())
    UInt32 => {
      let n = reader.uint32()
      Json::number(n.to_double(), repr=n.to_string())
    }
    UInt64 => Json::string(reader.uint64().to_string())
    Enum(names) => Json::string(enum_name(names, reader.int32()))
    Message(name) => message_json(name, reader.block())
    Rep(_) => raise gateway_error(13, "gateway: a repetition reads one value")
  }
}

///|
/// The name of an enumeration value. A number the table does not know stays a
/// number, which is what the JSON mapping does for unknown values.
fn enum_name(names : Array[String], number : Int32) -> String {
  if number >= 0 && number < names.length() {
    names[number]
  } else {
    number.to_string()
  }
}

///|
/// The wire form of one message, from its gateway JSON.
fn message_wire(message : String, json : Json) -> Bytes raise EtcdError {
  let fields = gateway_fields(message)
  let object = match json {
    Object(entries) => entries
    _ =>
      raise gateway_error(
        3,
        "gateway: " + message + " is expected as an object",
      )
  }
  let writer = @proto.PbWriter::new()
  for field in fields {
    match object.get(field.name) {
      None => ()
      Some(Null) => ()
      Some(value) =>
        match field.kind {
          Rep(item) =>
            match value {
              Array(items) =>
                for element in items {
                  write_value(writer, field, item, element)
                }
              _ =>
                raise gateway_error(
                  3,
                  "gateway: " +
                  message +
                  "." +
                  field.name +
                  " is expected as an array",
                )
            }
          kind => write_value(writer, field, kind, value)
        }
    }
  }
  writer.to_bytes()
}

///|
/// Write one value of a field into the message being built. A scalar holding the
/// default is left out, as every protobuf encoder does, unless the field is an arm
/// of a oneof — there the arm has to be present to be selected.
fn write_value(
  writer : @proto.PbWriter,
  field : JsonField,
  kind : FieldKind,
  value : Json,
) -> Unit raise EtcdError {
  match kind {
    Str => {
      let text = text_of(value, field.name)
      if field.presence || text != "" {
        writer.string_(field.number, text)
      }
    }
    Bytes => {
      let raw = bytes_of(value, field.name)
      if field.presence || raw.length() > 0 {
        writer.bytes_(field.number, raw)
      }
    }
    Bool => {
      let flag = match value {
        True => true
        False => false
        _ =>
          raise gateway_error(
            3,
            "gateway: " + field.name + " is expected as a bool",
          )
      }
      if field.presence || flag {
        writer.bool_(field.number, flag)
      }
    }
    Int64 => {
      let n = int64_of(value, field.name)
      if field.presence || n != 0L {
        writer.int64(field.number, n)
      }
    }
    UInt32 => {
      let n = uint64_of(value, field.name).to_uint()
      if field.presence || n != 0U {
        writer.uint32(field.number, n)
      }
    }
    UInt64 => {
      let n = uint64_of(value, field.name)
      if field.presence || n != 0UL {
        writer.uint64(field.number, n)
      }
    }
    Enum(names) => {
      let n = enum_number(names, value, field.name)
      if field.presence || n != 0 {
        writer.enum_(field.number, n)
      }
    }
    Message(name) => writer.message_(field.number, message_wire(name, value))
    Rep(_) => raise gateway_error(3, "gateway: a repetition writes one value")
  }
}

///|
/// A string value.
fn text_of(value : Json, field : String) -> String raise EtcdError {
  match value {
    String(text) => text
    _ =>
      raise gateway_error(3, "gateway: " + field + " is expected as a string")
  }
}

///|
/// A `bytes` value: standard base64, padded, as the JSON mapping requires.
fn bytes_of(value : Json, field : String) -> Bytes raise EtcdError {
  let text = text_of(value, field)
  if text == "" {
    return b""
  }
  @base64.decode(text[:]) catch {
    _ => raise gateway_error(3, "gateway: " + field + " is not base64")
  }
}

///|
/// The decimal text of a 64-bit value: the JSON mapping writes it as a string and an
/// encoder that writes a number instead is accepted too. `Double` cannot hold every
/// 64-bit value, so the text comes from the JSON literal rather than from a number
/// parsed out of it.
fn decimal_of(value : Json, field : String) -> String raise EtcdError {
  match value {
    String(text) => text
    Number(_, ..) => Json::stringify(value)
    _ =>
      raise gateway_error(3, "gateway: " + field + " is expected as a number")
  }
}

///|
fn int64_of(value : Json, field : String) -> Int64 raise EtcdError {
  let (negative, magnitude) = parse_digits(
    decimal_of(value, field),
    field,
    true,
  )
  let magnitude = magnitude.reinterpret_as_int64()
  if negative {
    0L - magnitude
  } else {
    magnitude
  }
}

///|
fn uint64_of(value : Json, field : String) -> UInt64 raise EtcdError {
  parse_digits(decimal_of(value, field), field, false).1
}

///|
/// The sign and magnitude of a decimal integer, refusing a value wider than the
/// field: a lease id or a revision that silently changes is worse than a failed call.
/// An `int64` reaches 2^63 either way and a `uint64` reaches 2^64 - 1.
fn parse_digits(
  text : String,
  field : String,
  signed : Bool,
) -> (Bool, UInt64) raise EtcdError {
  let digits = text.to_array()
  let mut i = 0
  let mut negative = false
  if i < digits.length() {
    let first = digits[i].to_int()
    if first == 45 || first == 43 {
      guard signed else {
        raise gateway_error(3, "gateway: " + field + " is not negative")
      }
      negative = first == 45
      i = i + 1
    }
  }
  guard i < digits.length() else {
    raise gateway_error(3, "gateway: " + field + " has no digits")
  }
  let limit : UInt64 = if !signed {
    18446744073709551615UL
  } else if negative {
    9223372036854775808UL
  } else {
    9223372036854775807UL
  }
  let width = if signed { "64 bits of a signed integer" } else { "64 bits" }
  let mut magnitude = 0UL
  while i < digits.length() {
    let digit = digits[i].to_int()
    guard digit >= 48 && digit <= 57 else {
      raise gateway_error(3, "gateway: " + field + " is not decimal")
    }
    magnitude = magnitude * 10UL + (digit - 48).to_uint64()
    guard magnitude <= limit else {
      raise gateway_error(3, "gateway: " + field + " overflows " + width)
    }
    i = i + 1
  }
  (negative, magnitude)
}

///|
/// The number of an enumeration value: its name, or a number for a value the table
/// does not name.
fn enum_number(
  names : Array[String],
  value : Json,
  field : String,
) -> Int32 raise EtcdError {
  match value {
    String(text) => {
      for i = 0; i < names.length(); i = i + 1 {
        if names[i] == text {
          return i
        }
      }
      int64_of(Json::string(text), field).to_int()
    }
    _ => int64_of(value, field).to_int()
  }
}
