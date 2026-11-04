// The value types etcd carries in its responses (`mvccpb`): a key/value with its
// revision history, and the event a watch delivers. Field numbers follow etcd's
// `mvccpb/kv.proto`, so a `KeyValue` encodes to the bytes a real etcd server sends.

///|
/// An etcd key/value (`mvccpb.KeyValue`): the key and value as raw bytes, the
/// create/mod revisions and version that track its history, and the lease it is
/// attached to.
#derive(Eq)
pub(all) struct KeyValue {
  key : Bytes
  create_revision : Int64
  mod_revision : Int64
  version : Int64
  value : Bytes
  lease : Int64
}

///|
pub extend KeyValue with Eq::{not_equal, equal}

///|
/// The empty key/value: all-zero metadata and no key or value.
pub fn KeyValue::empty() -> KeyValue {
  {
    key: b"",
    create_revision: 0,
    mod_revision: 0,
    version: 0,
    value: b"",
    lease: 0,
  }
}

///|
/// True when the key/value carries no data: the wire omits such a message.
pub fn KeyValue::is_empty(self : KeyValue) -> Bool {
  self.key.length() == 0 &&
  self.value.length() == 0 &&
  self.create_revision == 0 &&
  self.mod_revision == 0 &&
  self.version == 0 &&
  self.lease == 0
}

///|
/// Encode a `KeyValue` (key=1, create_revision=2, mod_revision=3, version=4,
/// value=5, lease=6). Proto3 omits zero/default fields.
pub fn KeyValue::encode(self : KeyValue) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.key.length() > 0 {
    w.bytes_(1, self.key)
  }
  if self.create_revision != 0 {
    w.int64(2, self.create_revision)
  }
  if self.mod_revision != 0 {
    w.int64(3, self.mod_revision)
  }
  if self.version != 0 {
    w.int64(4, self.version)
  }
  if self.value.length() > 0 {
    w.bytes_(5, self.value)
  }
  if self.lease != 0 {
    w.int64(6, self.lease)
  }
  w.to_bytes()
}

///|
/// Decode a `KeyValue`; unknown fields are skipped.
pub fn KeyValue::decode(data : Bytes) -> KeyValue raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut key = b""
  let mut create_revision = 0L
  let mut mod_revision = 0L
  let mut version = 0L
  let mut value = b""
  let mut lease = 0L
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => key = r.read_bytes()
      (2, Varint) => create_revision = r.read_int64()
      (3, Varint) => mod_revision = r.read_int64()
      (4, Varint) => version = r.read_int64()
      (5, LengthDelim) => value = r.read_bytes()
      (6, Varint) => lease = r.read_int64()
      (_, wire) => r.skip(wire)
    }
  }
  { key, create_revision, mod_revision, version, value, lease, }
}

///|
/// The kind of change a watch `Event` reports (`mvccpb.Event.EventType`): a key was
/// `Put` (created or updated) or `Delete`d. `PUT` (0) is the proto3 default.
#derive(Eq)
pub(all) enum EventType {
  Put = 0
  Delete = 1
}

///|
pub extend EventType with Eq::{not_equal, equal}

///|
pub fn EventType::to_int(self : EventType) -> Int32 {
  match self {
    Put => 0
    Delete => 1
  }
}

///|
/// The event type for a protobuf enum number; unknown numbers read as `Put`, as
/// etcd (and Go's proto) default an unknown enum to its first value.
pub fn EventType::from_int(n : Int32) -> EventType {
  if n == 1 {
    Delete
  } else {
    Put
  }
}

///|
/// A watch `Event` (`mvccpb.Event`): one change to one key, carrying the resulting
/// `KeyValue` and, when the request asked for it, the previous one.
#derive(Eq)
pub(all) struct Event {
  event_type : EventType
  kv : KeyValue
  prev_kv : KeyValue
}

///|
pub extend Event with Eq::{not_equal, equal}

///|
pub fn Event::empty() -> Event {
  { event_type: Put, kv: KeyValue::empty(), prev_kv: KeyValue::empty(), }
}

///|
/// Encode an `Event` (type=1, kv=2, prev_kv=3). `PUT` (0) is omitted.
pub fn Event::encode(self : Event) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.event_type.to_int() != 0 {
    w.enum_(1, self.event_type.to_int())
  }
  w.message_(2, self.kv.encode())
  if !self.prev_kv.is_empty() {
    w.message_(3, self.prev_kv.encode())
  }
  w.to_bytes()
}

///|
/// Decode an `Event`; an absent `prev_kv` decodes to the empty key/value.
pub fn Event::decode(data : Bytes) -> Event raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut event_type = EventType::Put
  let mut kv = KeyValue::empty()
  let mut prev_kv = KeyValue::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, Varint) => event_type = EventType::from_int(r.read_int32())
      (2, LengthDelim) => kv = KeyValue::decode(r.read_bytes())
      (3, LengthDelim) => prev_kv = KeyValue::decode(r.read_bytes())
      (_, wire) => r.skip(wire)
    }
  }
  { event_type, kv, prev_kv, }
}
