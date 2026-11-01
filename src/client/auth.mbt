// Auth: enable/disable authentication and manage users and roles
// (etcdserverpb.Auth). The empty requests (enable, disable, status, user/role list)
// are sent as an empty body, which is a valid encoding of the empty message.

///|
/// A typed handle for the Auth service. Obtain it with `client.auth()`.
pub struct Auth {
  client : Client
}

///|
/// Turn authentication on. From here on, calls need a token.
pub async fn Auth::enable(self : Auth) -> AuthEnableResponse raise EtcdError {
  self.client.rpc(
    "/etcdserverpb.Auth/AuthEnable",
    b"",
    @moonetcd.AuthEnableResponse::decode,
  )
}

///|
/// Turn authentication off.
pub async fn Auth::disable(self : Auth) -> AuthDisableResponse raise EtcdError {
  self.client.rpc(
    "/etcdserverpb.Auth/AuthDisable",
    b"",
    @moonetcd.AuthDisableResponse::decode,
  )
}

///|
/// Report whether authentication is enabled and the current auth revision.
pub async fn Auth::status(self : Auth) -> AuthStatusResponse raise EtcdError {
  self.client.rpc(
    "/etcdserverpb.Auth/AuthStatus",
    b"",
    @moonetcd.AuthStatusResponse::decode,
  )
}

///|
/// Create user `name` with `password`; `no_password` creates a user without one.
pub async fn Auth::user_add(
  self : Auth,
  name : String,
  password : String,
  no_password? : Bool,
) -> AuthUserAddResponse raise EtcdError {
  let req = @moonetcd.AuthUserAddRequest::{
    name,
    password,
    options: @moonetcd.UserAddOptions::{
      no_password: no_password.unwrap_or(false),
    },
  }
  self.client.rpc(
    "/etcdserverpb.Auth/UserAdd",
    req.encode(),
    @moonetcd.AuthUserAddResponse::decode,
  )
}

///|
/// Delete user `name`.
pub async fn Auth::user_delete(
  self : Auth,
  name : String,
) -> AuthUserDeleteResponse raise EtcdError {
  let req = @moonetcd.AuthUserDeleteRequest::{ name, }
  self.client.rpc(
    "/etcdserverpb.Auth/UserDelete",
    req.encode(),
    @moonetcd.AuthUserDeleteResponse::decode,
  )
}

///|
/// Change user `name`'s password.
pub async fn Auth::user_change_password(
  self : Auth,
  name : String,
  password : String,
) -> AuthUserChangePasswordResponse raise EtcdError {
  let req = @moonetcd.AuthUserChangePasswordRequest::{ name, password, }
  self.client.rpc(
    "/etcdserverpb.Auth/UserChangePassword",
    req.encode(),
    @moonetcd.AuthUserChangePasswordResponse::decode,
  )
}

///|
/// Grant role `role` to user `user`.
pub async fn Auth::user_grant_role(
  self : Auth,
  user : String,
  role : String,
) -> AuthUserGrantRoleResponse raise EtcdError {
  let req = @moonetcd.AuthUserGrantRoleRequest::{ user, role, }
  self.client.rpc(
    "/etcdserverpb.Auth/UserGrantRole",
    req.encode(),
    @moonetcd.AuthUserGrantRoleResponse::decode,
  )
}

///|
/// Revoke role `role` from user `name`.
pub async fn Auth::user_revoke_role(
  self : Auth,
  name : String,
  role : String,
) -> AuthUserRevokeRoleResponse raise EtcdError {
  let req = @moonetcd.AuthUserRevokeRoleRequest::{ name, role, }
  self.client.rpc(
    "/etcdserverpb.Auth/UserRevokeRole",
    req.encode(),
    @moonetcd.AuthUserRevokeRoleResponse::decode,
  )
}

///|
/// The roles held by user `name`.
pub async fn Auth::user_get(
  self : Auth,
  name : String,
) -> AuthUserGetResponse raise EtcdError {
  let req = @moonetcd.AuthUserGetRequest::{ name, }
  self.client.rpc(
    "/etcdserverpb.Auth/UserGet",
    req.encode(),
    @moonetcd.AuthUserGetResponse::decode,
  )
}

///|
/// Every user name.
pub async fn Auth::user_list(
  self : Auth,
) -> AuthUserListResponse raise EtcdError {
  self.client.rpc(
    "/etcdserverpb.Auth/UserList",
    b"",
    @moonetcd.AuthUserListResponse::decode,
  )
}

///|
/// Create role `name`.
pub async fn Auth::role_add(
  self : Auth,
  name : String,
) -> AuthRoleAddResponse raise EtcdError {
  let req = @moonetcd.AuthRoleAddRequest::{ name, }
  self.client.rpc(
    "/etcdserverpb.Auth/RoleAdd",
    req.encode(),
    @moonetcd.AuthRoleAddResponse::decode,
  )
}

///|
/// Delete role `role`.
pub async fn Auth::role_delete(
  self : Auth,
  role : String,
) -> AuthRoleDeleteResponse raise EtcdError {
  let req = @moonetcd.AuthRoleDeleteRequest::{ role, }
  self.client.rpc(
    "/etcdserverpb.Auth/RoleDelete",
    req.encode(),
    @moonetcd.AuthRoleDeleteResponse::decode,
  )
}

///|
/// Grant `perm` to role `name`.
pub async fn Auth::role_grant_permission(
  self : Auth,
  name : String,
  perm : Permission,
) -> AuthRoleGrantPermissionResponse raise EtcdError {
  let req = @moonetcd.AuthRoleGrantPermissionRequest::{ name, perm, }
  self.client.rpc(
    "/etcdserverpb.Auth/RoleGrantPermission",
    req.encode(),
    @moonetcd.AuthRoleGrantPermissionResponse::decode,
  )
}

///|
/// Revoke the permission on `[key, range_end)` from role `role`.
pub async fn Auth::role_revoke_permission(
  self : Auth,
  role : String,
  key : Bytes,
  range_end : Bytes,
) -> AuthRoleRevokePermissionResponse raise EtcdError {
  let req = @moonetcd.AuthRoleRevokePermissionRequest::{ role, key, range_end, }
  self.client.rpc(
    "/etcdserverpb.Auth/RoleRevokePermission",
    req.encode(),
    @moonetcd.AuthRoleRevokePermissionResponse::decode,
  )
}

///|
/// The permissions granted to role `role`.
pub async fn Auth::role_get(
  self : Auth,
  role : String,
) -> AuthRoleGetResponse raise EtcdError {
  let req = @moonetcd.AuthRoleGetRequest::{ role, }
  self.client.rpc(
    "/etcdserverpb.Auth/RoleGet",
    req.encode(),
    @moonetcd.AuthRoleGetResponse::decode,
  )
}

///|
/// Every role name.
pub async fn Auth::role_list(
  self : Auth,
) -> AuthRoleListResponse raise EtcdError {
  self.client.rpc(
    "/etcdserverpb.Auth/RoleList",
    b"",
    @moonetcd.AuthRoleListResponse::decode,
  )
}
