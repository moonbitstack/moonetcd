// Key layout helpers. etcd stores keys and values as opaque bytes and answers
// range queries over the half-open `[key, end)` interval, so a prefix scan is the
// prefix followed by an end key one past it.

///|
/// The half-open `[key, end)` range that covers every key sharing `key` as a
/// byte prefix. The end is `key` with its final byte incremented, dropping that
/// byte when it would overflow `0xff` — the rule etcd's own `prefix` follows.
pub fn prefix_range(key : Bytes) -> (Bytes, Bytes) {
  let n = key.length()
  if n == 0 {
    return (key, key)
  }
  let end = key.to_array()
  let mut i = n - 1
  while i >= 0 {
    if end[i].to_int() != 255 {
      end[i] = (end[i].to_int() + 1).to_byte()
      return (key, Bytes::from_array(end))
    }
    let _ = end.remove(i)
    i = i - 1
  }
  (key, Bytes::from_array(end))
}

///|
/// The end key of `prefix_range`: one past every key with `key` as its prefix.
pub fn prefix(key : Bytes) -> Bytes {
  prefix_range(key).1
}

///|
/// The range that covers exactly `key` and nothing else: `[key, key + 1)`.
pub fn exact(key : Bytes) -> (Bytes, Bytes) {
  prefix_range(key)
}

///|
/// True when `key` begins with `prefix` as a byte sequence.
pub fn has_prefix(key : Bytes, prefix : Bytes) -> Bool {
  let plen = prefix.length()
  if key.length() < plen {
    return false
  }
  for i = 0; i < plen; i = i + 1 {
    if key[i] != prefix[i] {
      return false
    }
  }
  true
}
