// The Auth service (`etcdserverpb`): users, roles, and the permissions granted to
// them. Field numbers follow etcd's `auth.proto`.

///|
/// The kind of access a `Permission` grants (`etcdserverpb.Permission.Type`).
pub(all) enum PermissionType {
  Read = 0
  Write = 1
  ReadWrite = 2
} derive(Eq)

///|
pub extend PermissionType with Eq::{not_equal, equal}

///|
pub fn PermissionType::to_int(self : PermissionType) -> Int32 {
  match self {
    Read => 0
    Write => 1
    ReadWrite => 2
  }
}

///|
pub fn PermissionType::from_int(n : Int32) -> PermissionType {
  if n == 1 {
    Write
  } else if n == 2 {
    ReadWrite
  } else {
    Read
  }
}

///|
/// A grant over `[key, range_end)` (`etcdserverpb.Permission`).
pub(all) struct Permission {
  key : Bytes
  range_end : Bytes
  perm_type : PermissionType
  name : String
} derive(Eq)

///|
pub extend Permission with Eq::{not_equal, equal}

///|
pub fn Permission::empty() -> Permission {
  { key: b"", range_end: b"", perm_type: Read, name: "", }
}

///|
pub fn Permission::encode(self : Permission) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.key.length() > 0 {
    w.bytes_(1, self.key)
  }
  if self.range_end.length() > 0 {
    w.bytes_(2, self.range_end)
  }
  if self.perm_type.to_int() != 0 {
    w.enum_(3, self.perm_type.to_int())
  }
  if self.name.length() > 0 {
    w.string_(4, self.name)
  }
  w.to_bytes()
}

///|
pub fn Permission::decode(data : Bytes) -> Permission raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut p = Permission::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => p = { ..p, key: r.read_bytes(), }
      (2, LengthDelim) => p = { ..p, range_end: r.read_bytes(), }
      (3, Varint) =>
        p = { ..p, perm_type: PermissionType::from_int(r.read_int32()), }
      (4, LengthDelim) => p = { ..p, name: r.read_string(), }
      (_, wire) => r.skip(wire)
    }
  }
  p
}

///|
pub fn AuthEnableResponse::empty() -> AuthEnableResponse {
  { header: ResponseHeader::empty(), }
}

///|
/// Enable authentication (`etcdserverpb.AuthEnableResponse`).
pub(all) struct AuthEnableResponse {
  header : ResponseHeader
} derive(Eq)

///|
pub extend AuthEnableResponse with Eq::{not_equal, equal}

///|
pub fn AuthEnableResponse::encode(self : AuthEnableResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  w.to_bytes()
}

///|
pub fn AuthEnableResponse::decode(
  data : Bytes,
) -> AuthEnableResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut header = ResponseHeader::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => header = ResponseHeader::decode(r.read_bytes())
      (_, wire) => r.skip(wire)
    }
  }
  { header, }
}

///|
pub fn AuthDisableResponse::empty() -> AuthDisableResponse {
  { header: ResponseHeader::empty(), }
}

///|
/// Disable authentication (`etcdserverpb.AuthDisableResponse`).
pub(all) struct AuthDisableResponse {
  header : ResponseHeader
} derive(Eq)

///|
pub extend AuthDisableResponse with Eq::{not_equal, equal}

///|
pub fn AuthDisableResponse::encode(self : AuthDisableResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  w.to_bytes()
}

///|
pub fn AuthDisableResponse::decode(
  data : Bytes,
) -> AuthDisableResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut header = ResponseHeader::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => header = ResponseHeader::decode(r.read_bytes())
      (_, wire) => r.skip(wire)
    }
  }
  { header, }
}

///|
pub fn AuthStatusResponse::empty() -> AuthStatusResponse {
  { header: ResponseHeader::empty(), enabled: false, auth_revision: 0, }
}

///|
/// Whether authentication is on and the current auth revision
/// (`etcdserverpb.AuthStatusResponse`).
pub(all) struct AuthStatusResponse {
  header : ResponseHeader
  enabled : Bool
  auth_revision : Int64
} derive(Eq)

///|
pub extend AuthStatusResponse with Eq::{not_equal, equal}

///|
pub fn AuthStatusResponse::encode(self : AuthStatusResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  if self.enabled {
    w.bool_(2, self.enabled)
  }
  if self.auth_revision != 0 {
    w.int64(3, self.auth_revision)
  }
  w.to_bytes()
}

///|
pub fn AuthStatusResponse::decode(
  data : Bytes,
) -> AuthStatusResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut resp = AuthStatusResponse::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) =>
        resp = { ..resp, header: ResponseHeader::decode(r.read_bytes()), }
      (2, Varint) => resp = { ..resp, enabled: r.read_bool(), }
      (3, Varint) => resp = { ..resp, auth_revision: r.read_int64(), }
      (_, wire) => r.skip(wire)
    }
  }
  resp
}

///|
/// Exchange a name and password for a token (`etcdserverpb.AuthenticateRequest`).
pub(all) struct AuthenticateRequest {
  name : String
  password : String
} derive(Eq)

///|
pub extend AuthenticateRequest with Eq::{not_equal, equal}

///|
pub fn AuthenticateRequest::empty() -> AuthenticateRequest {
  { name: "", password: "", }
}

///|
pub fn AuthenticateRequest::encode(self : AuthenticateRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.name.length() > 0 {
    w.string_(1, self.name)
  }
  if self.password.length() > 0 {
    w.string_(2, self.password)
  }
  w.to_bytes()
}

///|
pub fn AuthenticateRequest::decode(
  data : Bytes,
) -> AuthenticateRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = AuthenticateRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => req = { ..req, name: r.read_string(), }
      (2, LengthDelim) => req = { ..req, password: r.read_string(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn AuthenticateResponse::empty() -> AuthenticateResponse {
  { header: ResponseHeader::empty(), token: "", }
}

///|
/// The issued token (`etcdserverpb.AuthenticateResponse`).
pub(all) struct AuthenticateResponse {
  header : ResponseHeader
  token : String
} derive(Eq)

///|
pub extend AuthenticateResponse with Eq::{not_equal, equal}

///|
pub fn AuthenticateResponse::encode(self : AuthenticateResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  if self.token.length() > 0 {
    w.string_(2, self.token)
  }
  w.to_bytes()
}

///|
pub fn AuthenticateResponse::decode(
  data : Bytes,
) -> AuthenticateResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut resp = AuthenticateResponse::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) =>
        resp = { ..resp, header: ResponseHeader::decode(r.read_bytes()), }
      (2, LengthDelim) => resp = { ..resp, token: r.read_string(), }
      (_, wire) => r.skip(wire)
    }
  }
  resp
}

///|
pub fn UserAddOptions::empty() -> UserAddOptions {
  { no_password: false, }
}

///|
/// Options for adding a user (`etcdserverpb.UserAddOptions`).
pub(all) struct UserAddOptions {
  no_password : Bool
} derive(Eq)

///|
pub extend UserAddOptions with Eq::{not_equal, equal}

///|
pub fn UserAddOptions::encode(self : UserAddOptions) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.no_password {
    w.bool_(1, self.no_password)
  }
  w.to_bytes()
}

///|
pub fn UserAddOptions::decode(
  data : Bytes,
) -> UserAddOptions raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut o = UserAddOptions::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, Varint) => o = { no_password: r.read_bool(), }
      (_, wire) => r.skip(wire)
    }
  }
  o
}

///|
/// Add a user (`etcdserverpb.AuthUserAddRequest`).
pub(all) struct AuthUserAddRequest {
  name : String
  password : String
  options : UserAddOptions
} derive(Eq)

///|
pub extend AuthUserAddRequest with Eq::{not_equal, equal}

///|
pub fn AuthUserAddRequest::empty() -> AuthUserAddRequest {
  { name: "", password: "", options: UserAddOptions::empty(), }
}

///|
pub fn AuthUserAddRequest::encode(self : AuthUserAddRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.name.length() > 0 {
    w.string_(1, self.name)
  }
  if self.password.length() > 0 {
    w.string_(2, self.password)
  }
  if self.options != UserAddOptions::empty() {
    w.message_(3, self.options.encode())
  }
  w.to_bytes()
}

///|
pub fn AuthUserAddRequest::decode(
  data : Bytes,
) -> AuthUserAddRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = AuthUserAddRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => req = { ..req, name: r.read_string(), }
      (2, LengthDelim) => req = { ..req, password: r.read_string(), }
      (3, LengthDelim) =>
        req = { ..req, options: UserAddOptions::decode(r.read_bytes()), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn AuthUserAddResponse::empty() -> AuthUserAddResponse {
  { header: ResponseHeader::empty(), }
}

///|
/// Added-user reply (`etcdserverpb.AuthUserAddResponse`).
pub(all) struct AuthUserAddResponse {
  header : ResponseHeader
} derive(Eq)

///|
pub extend AuthUserAddResponse with Eq::{not_equal, equal}

///|
pub fn AuthUserAddResponse::encode(self : AuthUserAddResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  w.to_bytes()
}

///|
pub fn AuthUserAddResponse::decode(
  data : Bytes,
) -> AuthUserAddResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut header = ResponseHeader::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => header = ResponseHeader::decode(r.read_bytes())
      (_, wire) => r.skip(wire)
    }
  }
  { header, }
}

///|
/// Fetch a user's roles (`etcdserverpb.AuthUserGetRequest`).
pub(all) struct AuthUserGetRequest {
  name : String
} derive(Eq)

///|
pub extend AuthUserGetRequest with Eq::{not_equal, equal}

///|
pub fn AuthUserGetRequest::empty() -> AuthUserGetRequest {
  { name: "", }
}

///|
pub fn AuthUserGetRequest::encode(self : AuthUserGetRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.name.length() > 0 {
    w.string_(1, self.name)
  }
  w.to_bytes()
}

///|
pub fn AuthUserGetRequest::decode(
  data : Bytes,
) -> AuthUserGetRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = AuthUserGetRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => req = { name: r.read_string(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn AuthUserGetResponse::empty() -> AuthUserGetResponse {
  { header: ResponseHeader::empty(), roles: [], }
}

///|
/// A user's roles (`etcdserverpb.AuthUserGetResponse`).
pub(all) struct AuthUserGetResponse {
  header : ResponseHeader
  roles : Array[String]
} derive(Eq)

///|
pub extend AuthUserGetResponse with Eq::{not_equal, equal}

///|
pub fn AuthUserGetResponse::encode(self : AuthUserGetResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  for rname in self.roles {
    w.string_(2, rname)
  }
  w.to_bytes()
}

///|
pub fn AuthUserGetResponse::decode(
  data : Bytes,
) -> AuthUserGetResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut resp = AuthUserGetResponse::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) =>
        resp = { ..resp, header: ResponseHeader::decode(r.read_bytes()), }
      (2, LengthDelim) => resp.roles.push(r.read_string())
      (_, wire) => r.skip(wire)
    }
  }
  resp
}

///|
pub fn AuthUserListResponse::empty() -> AuthUserListResponse {
  { header: ResponseHeader::empty(), users: [], }
}

///|
/// All user names (`etcdserverpb.AuthUserListResponse`).
pub(all) struct AuthUserListResponse {
  header : ResponseHeader
  users : Array[String]
} derive(Eq)

///|
pub extend AuthUserListResponse with Eq::{not_equal, equal}

///|
pub fn AuthUserListResponse::encode(self : AuthUserListResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  for u in self.users {
    w.string_(2, u)
  }
  w.to_bytes()
}

///|
pub fn AuthUserListResponse::decode(
  data : Bytes,
) -> AuthUserListResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut resp = AuthUserListResponse::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) =>
        resp = { ..resp, header: ResponseHeader::decode(r.read_bytes()), }
      (2, LengthDelim) => resp.users.push(r.read_string())
      (_, wire) => r.skip(wire)
    }
  }
  resp
}

///|
/// Delete a user (`etcdserverpb.AuthUserDeleteRequest`).
pub(all) struct AuthUserDeleteRequest {
  name : String
} derive(Eq)

///|
pub extend AuthUserDeleteRequest with Eq::{not_equal, equal}

///|
pub fn AuthUserDeleteRequest::empty() -> AuthUserDeleteRequest {
  { name: "", }
}

///|
pub fn AuthUserDeleteRequest::encode(self : AuthUserDeleteRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.name.length() > 0 {
    w.string_(1, self.name)
  }
  w.to_bytes()
}

///|
pub fn AuthUserDeleteRequest::decode(
  data : Bytes,
) -> AuthUserDeleteRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = AuthUserDeleteRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => req = { name: r.read_string(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn AuthUserDeleteResponse::empty() -> AuthUserDeleteResponse {
  { header: ResponseHeader::empty(), }
}

///|
/// Deleted-user reply (`etcdserverpb.AuthUserDeleteResponse`).
pub(all) struct AuthUserDeleteResponse {
  header : ResponseHeader
} derive(Eq)

///|
pub extend AuthUserDeleteResponse with Eq::{not_equal, equal}

///|
pub fn AuthUserDeleteResponse::encode(self : AuthUserDeleteResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  w.to_bytes()
}

///|
pub fn AuthUserDeleteResponse::decode(
  data : Bytes,
) -> AuthUserDeleteResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut header = ResponseHeader::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => header = ResponseHeader::decode(r.read_bytes())
      (_, wire) => r.skip(wire)
    }
  }
  { header, }
}

///|
/// Change a user's password (`etcdserverpb.AuthUserChangePasswordRequest`).
pub(all) struct AuthUserChangePasswordRequest {
  name : String
  password : String
} derive(Eq)

///|
pub extend AuthUserChangePasswordRequest with Eq::{not_equal, equal}

///|
pub fn AuthUserChangePasswordRequest::empty() -> AuthUserChangePasswordRequest {
  { name: "", password: "", }
}

///|
pub fn AuthUserChangePasswordRequest::encode(
  self : AuthUserChangePasswordRequest,
) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.name.length() > 0 {
    w.string_(1, self.name)
  }
  if self.password.length() > 0 {
    w.string_(2, self.password)
  }
  w.to_bytes()
}

///|
pub fn AuthUserChangePasswordRequest::decode(
  data : Bytes,
) -> AuthUserChangePasswordRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = AuthUserChangePasswordRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => req = { ..req, name: r.read_string(), }
      (2, LengthDelim) => req = { ..req, password: r.read_string(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn AuthUserChangePasswordResponse::empty() -> AuthUserChangePasswordResponse {
  { header: ResponseHeader::empty(), }
}

///|
/// Changed-password reply (`etcdserverpb.AuthUserChangePasswordResponse`).
pub(all) struct AuthUserChangePasswordResponse {
  header : ResponseHeader
} derive(Eq)

///|
pub extend AuthUserChangePasswordResponse with Eq::{not_equal, equal}

///|
pub fn AuthUserChangePasswordResponse::encode(
  self : AuthUserChangePasswordResponse,
) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  w.to_bytes()
}

///|
pub fn AuthUserChangePasswordResponse::decode(
  data : Bytes,
) -> AuthUserChangePasswordResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut header = ResponseHeader::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => header = ResponseHeader::decode(r.read_bytes())
      (_, wire) => r.skip(wire)
    }
  }
  { header, }
}

///|
/// Grant a role to a user (`etcdserverpb.AuthUserGrantRoleRequest`).
pub(all) struct AuthUserGrantRoleRequest {
  user : String
  role : String
} derive(Eq)

///|
pub extend AuthUserGrantRoleRequest with Eq::{not_equal, equal}

///|
pub fn AuthUserGrantRoleRequest::empty() -> AuthUserGrantRoleRequest {
  { user: "", role: "", }
}

///|
pub fn AuthUserGrantRoleRequest::encode(
  self : AuthUserGrantRoleRequest,
) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.user.length() > 0 {
    w.string_(1, self.user)
  }
  if self.role.length() > 0 {
    w.string_(2, self.role)
  }
  w.to_bytes()
}

///|
pub fn AuthUserGrantRoleRequest::decode(
  data : Bytes,
) -> AuthUserGrantRoleRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = AuthUserGrantRoleRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => req = { ..req, user: r.read_string(), }
      (2, LengthDelim) => req = { ..req, role: r.read_string(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn AuthUserGrantRoleResponse::empty() -> AuthUserGrantRoleResponse {
  { header: ResponseHeader::empty(), }
}

///|
/// Granted-role reply (`etcdserverpb.AuthUserGrantRoleResponse`).
pub(all) struct AuthUserGrantRoleResponse {
  header : ResponseHeader
} derive(Eq)

///|
pub extend AuthUserGrantRoleResponse with Eq::{not_equal, equal}

///|
pub fn AuthUserGrantRoleResponse::encode(
  self : AuthUserGrantRoleResponse,
) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  w.to_bytes()
}

///|
pub fn AuthUserGrantRoleResponse::decode(
  data : Bytes,
) -> AuthUserGrantRoleResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut header = ResponseHeader::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => header = ResponseHeader::decode(r.read_bytes())
      (_, wire) => r.skip(wire)
    }
  }
  { header, }
}

///|
/// Revoke a role from a user (`etcdserverpb.AuthUserRevokeRoleRequest`).
pub(all) struct AuthUserRevokeRoleRequest {
  name : String
  role : String
} derive(Eq)

///|
pub extend AuthUserRevokeRoleRequest with Eq::{not_equal, equal}

///|
pub fn AuthUserRevokeRoleRequest::empty() -> AuthUserRevokeRoleRequest {
  { name: "", role: "", }
}

///|
pub fn AuthUserRevokeRoleRequest::encode(
  self : AuthUserRevokeRoleRequest,
) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.name.length() > 0 {
    w.string_(1, self.name)
  }
  if self.role.length() > 0 {
    w.string_(2, self.role)
  }
  w.to_bytes()
}

///|
pub fn AuthUserRevokeRoleRequest::decode(
  data : Bytes,
) -> AuthUserRevokeRoleRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = AuthUserRevokeRoleRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => req = { ..req, name: r.read_string(), }
      (2, LengthDelim) => req = { ..req, role: r.read_string(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn AuthUserRevokeRoleResponse::empty() -> AuthUserRevokeRoleResponse {
  { header: ResponseHeader::empty(), }
}

///|
/// Revoked-role reply (`etcdserverpb.AuthUserRevokeRoleResponse`).
pub(all) struct AuthUserRevokeRoleResponse {
  header : ResponseHeader
} derive(Eq)

///|
pub extend AuthUserRevokeRoleResponse with Eq::{not_equal, equal}

///|
pub fn AuthUserRevokeRoleResponse::encode(
  self : AuthUserRevokeRoleResponse,
) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  w.to_bytes()
}

///|
pub fn AuthUserRevokeRoleResponse::decode(
  data : Bytes,
) -> AuthUserRevokeRoleResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut header = ResponseHeader::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => header = ResponseHeader::decode(r.read_bytes())
      (_, wire) => r.skip(wire)
    }
  }
  { header, }
}

///|
/// Add a role (`etcdserverpb.AuthRoleAddRequest`).
pub(all) struct AuthRoleAddRequest {
  name : String
} derive(Eq)

///|
pub extend AuthRoleAddRequest with Eq::{not_equal, equal}

///|
pub fn AuthRoleAddRequest::empty() -> AuthRoleAddRequest {
  { name: "", }
}

///|
pub fn AuthRoleAddRequest::encode(self : AuthRoleAddRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.name.length() > 0 {
    w.string_(1, self.name)
  }
  w.to_bytes()
}

///|
pub fn AuthRoleAddRequest::decode(
  data : Bytes,
) -> AuthRoleAddRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = AuthRoleAddRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => req = { name: r.read_string(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn AuthRoleAddResponse::empty() -> AuthRoleAddResponse {
  { header: ResponseHeader::empty(), }
}

///|
/// Added-role reply (`etcdserverpb.AuthRoleAddResponse`).
pub(all) struct AuthRoleAddResponse {
  header : ResponseHeader
} derive(Eq)

///|
pub extend AuthRoleAddResponse with Eq::{not_equal, equal}

///|
pub fn AuthRoleAddResponse::encode(self : AuthRoleAddResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  w.to_bytes()
}

///|
pub fn AuthRoleAddResponse::decode(
  data : Bytes,
) -> AuthRoleAddResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut header = ResponseHeader::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => header = ResponseHeader::decode(r.read_bytes())
      (_, wire) => r.skip(wire)
    }
  }
  { header, }
}

///|
/// Fetch a role's permissions (`etcdserverpb.AuthRoleGetRequest`).
pub(all) struct AuthRoleGetRequest {
  role : String
} derive(Eq)

///|
pub extend AuthRoleGetRequest with Eq::{not_equal, equal}

///|
pub fn AuthRoleGetRequest::empty() -> AuthRoleGetRequest {
  { role: "", }
}

///|
pub fn AuthRoleGetRequest::encode(self : AuthRoleGetRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.role.length() > 0 {
    w.string_(1, self.role)
  }
  w.to_bytes()
}

///|
pub fn AuthRoleGetRequest::decode(
  data : Bytes,
) -> AuthRoleGetRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = AuthRoleGetRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => req = { role: r.read_string(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn AuthRoleGetResponse::empty() -> AuthRoleGetResponse {
  { header: ResponseHeader::empty(), perm: [], }
}

///|
/// A role's permissions (`etcdserverpb.AuthRoleGetResponse`).
pub(all) struct AuthRoleGetResponse {
  header : ResponseHeader
  perm : Array[Permission]
} derive(Eq)

///|
pub extend AuthRoleGetResponse with Eq::{not_equal, equal}

///|
pub fn AuthRoleGetResponse::encode(self : AuthRoleGetResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  for p in self.perm {
    w.message_(2, p.encode())
  }
  w.to_bytes()
}

///|
pub fn AuthRoleGetResponse::decode(
  data : Bytes,
) -> AuthRoleGetResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut resp = AuthRoleGetResponse::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) =>
        resp = { ..resp, header: ResponseHeader::decode(r.read_bytes()), }
      (2, LengthDelim) => resp.perm.push(Permission::decode(r.read_bytes()))
      (_, wire) => r.skip(wire)
    }
  }
  resp
}

///|
pub fn AuthRoleListResponse::empty() -> AuthRoleListResponse {
  { header: ResponseHeader::empty(), roles: [], }
}

///|
/// All role names (`etcdserverpb.AuthRoleListResponse`).
pub(all) struct AuthRoleListResponse {
  header : ResponseHeader
  roles : Array[String]
} derive(Eq)

///|
pub extend AuthRoleListResponse with Eq::{not_equal, equal}

///|
pub fn AuthRoleListResponse::encode(self : AuthRoleListResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  for rname in self.roles {
    w.string_(2, rname)
  }
  w.to_bytes()
}

///|
pub fn AuthRoleListResponse::decode(
  data : Bytes,
) -> AuthRoleListResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut resp = AuthRoleListResponse::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) =>
        resp = { ..resp, header: ResponseHeader::decode(r.read_bytes()), }
      (2, LengthDelim) => resp.roles.push(r.read_string())
      (_, wire) => r.skip(wire)
    }
  }
  resp
}

///|
/// Delete a role (`etcdserverpb.AuthRoleDeleteRequest`).
pub(all) struct AuthRoleDeleteRequest {
  role : String
} derive(Eq)

///|
pub extend AuthRoleDeleteRequest with Eq::{not_equal, equal}

///|
pub fn AuthRoleDeleteRequest::empty() -> AuthRoleDeleteRequest {
  { role: "", }
}

///|
pub fn AuthRoleDeleteRequest::encode(self : AuthRoleDeleteRequest) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.role.length() > 0 {
    w.string_(1, self.role)
  }
  w.to_bytes()
}

///|
pub fn AuthRoleDeleteRequest::decode(
  data : Bytes,
) -> AuthRoleDeleteRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = AuthRoleDeleteRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => req = { role: r.read_string(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn AuthRoleDeleteResponse::empty() -> AuthRoleDeleteResponse {
  { header: ResponseHeader::empty(), }
}

///|
/// Deleted-role reply (`etcdserverpb.AuthRoleDeleteResponse`).
pub(all) struct AuthRoleDeleteResponse {
  header : ResponseHeader
} derive(Eq)

///|
pub extend AuthRoleDeleteResponse with Eq::{not_equal, equal}

///|
pub fn AuthRoleDeleteResponse::encode(self : AuthRoleDeleteResponse) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  w.to_bytes()
}

///|
pub fn AuthRoleDeleteResponse::decode(
  data : Bytes,
) -> AuthRoleDeleteResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut header = ResponseHeader::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => header = ResponseHeader::decode(r.read_bytes())
      (_, wire) => r.skip(wire)
    }
  }
  { header, }
}

///|
/// Grant a permission to a role (`etcdserverpb.AuthRoleGrantPermissionRequest`).
pub(all) struct AuthRoleGrantPermissionRequest {
  name : String
  perm : Permission
} derive(Eq)

///|
pub extend AuthRoleGrantPermissionRequest with Eq::{not_equal, equal}

///|
pub fn AuthRoleGrantPermissionRequest::empty() -> AuthRoleGrantPermissionRequest {
  { name: "", perm: Permission::empty(), }
}

///|
pub fn AuthRoleGrantPermissionRequest::encode(
  self : AuthRoleGrantPermissionRequest,
) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.name.length() > 0 {
    w.string_(1, self.name)
  }
  if self.perm != Permission::empty() {
    w.message_(2, self.perm.encode())
  }
  w.to_bytes()
}

///|
pub fn AuthRoleGrantPermissionRequest::decode(
  data : Bytes,
) -> AuthRoleGrantPermissionRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = AuthRoleGrantPermissionRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => req = { ..req, name: r.read_string(), }
      (2, LengthDelim) =>
        req = { ..req, perm: Permission::decode(r.read_bytes()), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn AuthRoleGrantPermissionResponse::empty() -> AuthRoleGrantPermissionResponse {
  { header: ResponseHeader::empty(), }
}

///|
/// Granted-permission reply (`etcdserverpb.AuthRoleGrantPermissionResponse`).
pub(all) struct AuthRoleGrantPermissionResponse {
  header : ResponseHeader
} derive(Eq)

///|
pub extend AuthRoleGrantPermissionResponse with Eq::{not_equal, equal}

///|
pub fn AuthRoleGrantPermissionResponse::encode(
  self : AuthRoleGrantPermissionResponse,
) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  w.to_bytes()
}

///|
pub fn AuthRoleGrantPermissionResponse::decode(
  data : Bytes,
) -> AuthRoleGrantPermissionResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut header = ResponseHeader::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => header = ResponseHeader::decode(r.read_bytes())
      (_, wire) => r.skip(wire)
    }
  }
  { header, }
}

///|
/// Revoke a permission from a role (`etcdserverpb.AuthRoleRevokePermissionRequest`).
pub(all) struct AuthRoleRevokePermissionRequest {
  role : String
  key : Bytes
  range_end : Bytes
} derive(Eq)

///|
pub extend AuthRoleRevokePermissionRequest with Eq::{not_equal, equal}

///|
pub fn AuthRoleRevokePermissionRequest::empty() -> AuthRoleRevokePermissionRequest {
  { role: "", key: b"", range_end: b"", }
}

///|
pub fn AuthRoleRevokePermissionRequest::encode(
  self : AuthRoleRevokePermissionRequest,
) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.role.length() > 0 {
    w.string_(1, self.role)
  }
  if self.key.length() > 0 {
    w.bytes_(2, self.key)
  }
  if self.range_end.length() > 0 {
    w.bytes_(3, self.range_end)
  }
  w.to_bytes()
}

///|
pub fn AuthRoleRevokePermissionRequest::decode(
  data : Bytes,
) -> AuthRoleRevokePermissionRequest raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut req = AuthRoleRevokePermissionRequest::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => req = { ..req, role: r.read_string(), }
      (2, LengthDelim) => req = { ..req, key: r.read_bytes(), }
      (3, LengthDelim) => req = { ..req, range_end: r.read_bytes(), }
      (_, wire) => r.skip(wire)
    }
  }
  req
}

///|
pub fn AuthRoleRevokePermissionResponse::empty() -> AuthRoleRevokePermissionResponse {
  { header: ResponseHeader::empty(), }
}

///|
/// Revoked-permission reply (`etcdserverpb.AuthRoleRevokePermissionResponse`).
pub(all) struct AuthRoleRevokePermissionResponse {
  header : ResponseHeader
} derive(Eq)

///|
pub extend AuthRoleRevokePermissionResponse with Eq::{not_equal, equal}

///|
pub fn AuthRoleRevokePermissionResponse::encode(
  self : AuthRoleRevokePermissionResponse,
) -> Bytes {
  let w = @proto.PbWriter::new()
  if self.header != ResponseHeader::empty() {
    w.message_(1, self.header.encode())
  }
  w.to_bytes()
}

///|
pub fn AuthRoleRevokePermissionResponse::decode(
  data : Bytes,
) -> AuthRoleRevokePermissionResponse raise @proto.PbError {
  let r = @proto.PbReader::new(data)
  let mut header = ResponseHeader::empty()
  while !r.eof() {
    match r.read_tag() {
      (1, LengthDelim) => header = ResponseHeader::decode(r.read_bytes())
      (_, wire) => r.skip(wire)
    }
  }
  { header, }
}
