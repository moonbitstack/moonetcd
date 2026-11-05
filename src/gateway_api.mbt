// The HTTP/JSON gateway's address book: which URL each gRPC method answers on, and
// which two messages the call carries. etcd publishes the same services on both
// transports, so the mapping is a table and nothing else — a transport that has the
// table can serve every handle the gRPC transport serves.

///|
/// One call of etcd's HTTP/JSON gateway: the URL to `POST` to, the request message,
/// the reply message, and whether the reply arrives as a stream of messages rather
/// than as one.
pub(all) struct GatewayCall {
  path : String
  request : String
  reply : String
  streaming : Bool
}

///|
/// The call a gRPC method such as `/etcdserverpb.KV/Range` has on the gateway, or
/// `None` for a method etcd does not publish there.
pub fn gateway_call(grpc_method : String) -> GatewayCall? {
  match grpc_method {
    "/etcdserverpb.KV/Range" =>
      Some(unary("/v3/kv/range", "RangeRequest", "RangeResponse"))
    "/etcdserverpb.KV/Put" =>
      Some(unary("/v3/kv/put", "PutRequest", "PutResponse"))
    "/etcdserverpb.KV/DeleteRange" =>
      Some(
        unary("/v3/kv/deleterange", "DeleteRangeRequest", "DeleteRangeResponse"),
      )
    "/etcdserverpb.KV/Txn" =>
      Some(unary("/v3/kv/txn", "TxnRequest", "TxnResponse"))
    "/etcdserverpb.KV/Compact" =>
      Some(
        unary("/v3/kv/compaction", "CompactionRequest", "CompactionResponse"),
      )
    "/etcdserverpb.Lease/LeaseGrant" =>
      Some(unary("/v3/lease/grant", "LeaseGrantRequest", "LeaseGrantResponse"))
    "/etcdserverpb.Lease/LeaseRevoke" =>
      Some(
        unary("/v3/lease/revoke", "LeaseRevokeRequest", "LeaseRevokeResponse"),
      )
    "/etcdserverpb.Lease/LeaseTimeToLive" =>
      Some(
        unary(
          "/v3/lease/timetolive", "LeaseTimeToLiveRequest", "LeaseTimeToLiveResponse",
        ),
      )
    "/etcdserverpb.Lease/LeaseLeases" =>
      Some(
        unary("/v3/lease/leases", "LeaseLeasesRequest", "LeaseLeasesResponse"),
      )
    "/etcdserverpb.Lease/LeaseKeepAlive" =>
      Some(
        streamed(
          "/v3/lease/keepalive", "LeaseKeepAliveRequest", "LeaseKeepAliveResponse",
        ),
      )
    "/etcdserverpb.Watch/Watch" =>
      Some(streamed("/v3/watch", "WatchRequest", "WatchResponse"))
    "/etcdserverpb.Cluster/MemberAdd" =>
      Some(
        unary("/v3/cluster/member/add", "MemberAddRequest", "MemberAddResponse"),
      )
    "/etcdserverpb.Cluster/MemberRemove" =>
      Some(
        unary(
          "/v3/cluster/member/remove", "MemberRemoveRequest", "MemberRemoveResponse",
        ),
      )
    "/etcdserverpb.Cluster/MemberUpdate" =>
      Some(
        unary(
          "/v3/cluster/member/update", "MemberUpdateRequest", "MemberUpdateResponse",
        ),
      )
    "/etcdserverpb.Cluster/MemberList" =>
      Some(
        unary(
          "/v3/cluster/member/list", "MemberListRequest", "MemberListResponse",
        ),
      )
    "/etcdserverpb.Cluster/MemberPromote" =>
      Some(
        unary(
          "/v3/cluster/member/promote", "MemberPromoteRequest", "MemberPromoteResponse",
        ),
      )
    "/etcdserverpb.Maintenance/Alarm" =>
      Some(unary("/v3/maintenance/alarm", "AlarmRequest", "AlarmResponse"))
    "/etcdserverpb.Maintenance/Status" =>
      Some(unary("/v3/maintenance/status", "StatusRequest", "StatusResponse"))
    "/etcdserverpb.Maintenance/Defragment" =>
      Some(
        unary(
          "/v3/maintenance/defragment", "DefragmentRequest", "DefragmentResponse",
        ),
      )
    "/etcdserverpb.Maintenance/Hash" =>
      Some(unary("/v3/maintenance/hash", "HashRequest", "HashResponse"))
    "/etcdserverpb.Maintenance/HashKV" =>
      Some(unary("/v3/maintenance/hashkv", "HashKVRequest", "HashKVResponse"))
    "/etcdserverpb.Maintenance/Snapshot" =>
      Some(
        streamed(
          "/v3/maintenance/snapshot", "SnapshotRequest", "SnapshotResponse",
        ),
      )
    "/etcdserverpb.Maintenance/MoveLeader" =>
      Some(
        unary(
          "/v3/maintenance/transfer-leadership", "MoveLeaderRequest", "MoveLeaderResponse",
        ),
      )
    "/etcdserverpb.Maintenance/Downgrade" =>
      Some(
        unary(
          "/v3/maintenance/downgrade", "DowngradeRequest", "DowngradeResponse",
        ),
      )
    "/etcdserverpb.Auth/AuthEnable" =>
      Some(unary("/v3/auth/enable", "AuthEnableRequest", "AuthEnableResponse"))
    "/etcdserverpb.Auth/AuthDisable" =>
      Some(
        unary("/v3/auth/disable", "AuthDisableRequest", "AuthDisableResponse"),
      )
    "/etcdserverpb.Auth/AuthStatus" =>
      Some(unary("/v3/auth/status", "AuthStatusRequest", "AuthStatusResponse"))
    "/etcdserverpb.Auth/Authenticate" =>
      Some(
        unary(
          "/v3/auth/authenticate", "AuthenticateRequest", "AuthenticateResponse",
        ),
      )
    "/etcdserverpb.Auth/UserAdd" =>
      Some(
        unary("/v3/auth/user/add", "AuthUserAddRequest", "AuthUserAddResponse"),
      )
    "/etcdserverpb.Auth/UserGet" =>
      Some(
        unary("/v3/auth/user/get", "AuthUserGetRequest", "AuthUserGetResponse"),
      )
    "/etcdserverpb.Auth/UserList" =>
      Some(
        unary(
          "/v3/auth/user/list", "AuthUserListRequest", "AuthUserListResponse",
        ),
      )
    "/etcdserverpb.Auth/UserDelete" =>
      Some(
        unary(
          "/v3/auth/user/delete", "AuthUserDeleteRequest", "AuthUserDeleteResponse",
        ),
      )
    "/etcdserverpb.Auth/UserChangePassword" =>
      Some(
        unary(
          "/v3/auth/user/changepw", "AuthUserChangePasswordRequest", "AuthUserChangePasswordResponse",
        ),
      )
    "/etcdserverpb.Auth/UserGrantRole" =>
      Some(
        unary(
          "/v3/auth/user/grant", "AuthUserGrantRoleRequest", "AuthUserGrantRoleResponse",
        ),
      )
    "/etcdserverpb.Auth/UserRevokeRole" =>
      Some(
        unary(
          "/v3/auth/user/revoke", "AuthUserRevokeRoleRequest", "AuthUserRevokeRoleResponse",
        ),
      )
    "/etcdserverpb.Auth/RoleAdd" =>
      Some(
        unary("/v3/auth/role/add", "AuthRoleAddRequest", "AuthRoleAddResponse"),
      )
    "/etcdserverpb.Auth/RoleGet" =>
      Some(
        unary("/v3/auth/role/get", "AuthRoleGetRequest", "AuthRoleGetResponse"),
      )
    "/etcdserverpb.Auth/RoleList" =>
      Some(
        unary(
          "/v3/auth/role/list", "AuthRoleListRequest", "AuthRoleListResponse",
        ),
      )
    "/etcdserverpb.Auth/RoleDelete" =>
      Some(
        unary(
          "/v3/auth/role/delete", "AuthRoleDeleteRequest", "AuthRoleDeleteResponse",
        ),
      )
    "/etcdserverpb.Auth/RoleGrantPermission" =>
      Some(
        unary(
          "/v3/auth/role/grant", "AuthRoleGrantPermissionRequest", "AuthRoleGrantPermissionResponse",
        ),
      )
    "/etcdserverpb.Auth/RoleRevokePermission" =>
      Some(
        unary(
          "/v3/auth/role/revoke", "AuthRoleRevokePermissionRequest", "AuthRoleRevokePermissionResponse",
        ),
      )
    "/v3lockpb.Lock/Lock" =>
      Some(unary("/v3/lock/lock", "LockRequest", "LockResponse"))
    "/v3lockpb.Lock/Unlock" =>
      Some(unary("/v3/lock/unlock", "UnlockRequest", "UnlockResponse"))
    "/v3electionpb.Election/Campaign" =>
      Some(
        unary("/v3/election/campaign", "CampaignRequest", "CampaignResponse"),
      )
    "/v3electionpb.Election/Proclaim" =>
      Some(
        unary("/v3/election/proclaim", "ProclaimRequest", "ProclaimResponse"),
      )
    "/v3electionpb.Election/Leader" =>
      Some(unary("/v3/election/leader", "LeaderRequest", "LeaderResponse"))
    "/v3electionpb.Election/Observe" =>
      Some(unary("/v3/election/observe", "LeaderRequest", "LeaderResponse"))
    "/v3electionpb.Election/Resign" =>
      Some(unary("/v3/election/resign", "ResignRequest", "ResignResponse"))
    _ => None
  }
}

///|
fn unary(path : String, request : String, reply : String) -> GatewayCall {
  { path, request, reply, streaming: false, }
}

///|
fn streamed(path : String, request : String, reply : String) -> GatewayCall {
  { path, request, reply, streaming: true, }
}

///|
/// The JSON body that carries `body` — one request message in its wire form — to the
/// gateway.
pub fn GatewayCall::encode_request(
  self : GatewayCall,
  body : Bytes,
) -> String raise EtcdError {
  Json::stringify(message_json(self.request, body))
}

///|
/// The reply message in its wire form, from one JSON body or one JSON frame of a
/// streamed reply. A streamed reply wraps each message as `{"result": ...}`; an
/// error that ends a stream arrives in the same place, so it is read here rather
/// than surfacing as a missing field.
pub fn GatewayCall::decode_reply(
  self : GatewayCall,
  text : StringView,
) -> Bytes raise EtcdError {
  let json = @json.parse(text) catch {
    _ => raise gateway_error(13, "gateway: the reply is not JSON")
  }
  match json {
    Object(members) =>
      if members.get("code") is Some(_) && members.get("message") is Some(_) {
        raise gateway_failure(text)
      } else if self.streaming {
        match members.get("result") {
          Some(result) => message_wire(self.reply, result)
          None =>
            raise gateway_error(
              13,
              "gateway: a streamed reply has no result: " + text.to_owned(),
            )
        }
      } else {
        message_wire(self.reply, json)
      }
    _ => raise gateway_error(13, "gateway: the reply is not a JSON object")
  }
}

///|
/// The error a failed call ended with. The gateway answers with the gRPC status it
/// would have returned — `{"error": ..., "code": 3, "message": ...}` — so the same
/// mapping applies as over gRPC; a body that is not a status (a proxy in the way,
/// say) becomes `Refused` with what it did say.
pub fn gateway_failure(text : StringView) -> EtcdError {
  let json = @json.parse(text) catch {
    _ =>
      return EtcdError::Refused(Status::{ code: 2, message: text.to_owned(), })
  }
  match json {
    Object(members) => {
      let message = match members.get("message") {
        Some(String(message)) => message
        _ =>
          match members.get("error") {
            Some(String(error)) => error
            _ => text.to_owned()
          }
      }
      let code = match members.get("code") {
        Some(Number(code, ..)) => code.to_int()
        _ => 2
      }
      EtcdError::of(code, message)
    }
    _ => EtcdError::Refused(Status::{ code: 2, message: text.to_owned(), })
  }
}
