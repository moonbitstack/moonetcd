// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// What this does, and why it does it that way.
///
/// Doc comments are the published API documentation, so they say why rather
/// than what. Ordinary comments are for the surprises only.
pub fn greet(name : StringView) -> String {
  "hello, " + name.to_owned()
}
