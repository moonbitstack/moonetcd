// The messages of etcd's auth, maintenance, cluster, lock and election services, as
// the HTTP/JSON gateway names their fields. One entry per message; `gateway_json.mbt`
// reads it in both directions, and `scripts/check_field_numbers.py` checks it
// against etcd's .proto files.

///|
fn admin_message_fields(name : String) -> Array[JsonField]? {
  match name {
    "StatusRequest" => Some([])
    "DefragmentRequest" => Some([])
    "AuthUserListRequest" => Some([])
    "AuthStatusRequest" => Some([])
    "AuthRoleListRequest" => Some([])
    "AuthEnableRequest" => Some([])
    "AuthDisableRequest" => Some([])
    "AuthenticateRequest" =>
      Some([
        { number: 1, name: "name", kind: Str, presence: false, },
        { number: 2, name: "password", kind: Str, presence: false, },
      ])
    "AuthenticateResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
        { number: 2, name: "token", kind: Str, presence: false, },
      ])
    "AuthEnableResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
      ])
    "AuthDisableResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
      ])
    "AuthStatusResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
        { number: 2, name: "enabled", kind: Bool, presence: false, },
        { number: 3, name: "authRevision", kind: UInt64, presence: false, },
      ])
    "AuthUserAddRequest" =>
      Some([
        { number: 1, name: "name", kind: Str, presence: false, },
        { number: 2, name: "password", kind: Str, presence: false, },
        {
          number: 3,
          name: "options",
          kind: Message("UserAddOptions"),
          presence: false,
        },
        { number: 4, name: "hashedPassword", kind: Str, presence: false, },
      ])
    "AuthUserAddResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
      ])
    "UserAddOptions" =>
      Some([{ number: 1, name: "no_password", kind: Bool, presence: false, }])
    "AuthUserGetRequest" =>
      Some([{ number: 1, name: "name", kind: Str, presence: false, }])
    "AuthUserGetResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
        { number: 2, name: "roles", kind: Rep(Str), presence: false, },
      ])
    "AuthUserListResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
        { number: 2, name: "users", kind: Rep(Str), presence: false, },
      ])
    "AuthUserDeleteRequest" =>
      Some([{ number: 1, name: "name", kind: Str, presence: false, }])
    "AuthUserDeleteResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
      ])
    "AuthUserChangePasswordRequest" =>
      Some([
        { number: 1, name: "name", kind: Str, presence: false, },
        { number: 2, name: "password", kind: Str, presence: false, },
        { number: 3, name: "hashedPassword", kind: Str, presence: false, },
      ])
    "AuthUserChangePasswordResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
      ])
    "AuthUserGrantRoleRequest" =>
      Some([
        { number: 1, name: "user", kind: Str, presence: false, },
        { number: 2, name: "role", kind: Str, presence: false, },
      ])
    "AuthUserGrantRoleResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
      ])
    "AuthUserRevokeRoleRequest" =>
      Some([
        { number: 1, name: "name", kind: Str, presence: false, },
        { number: 2, name: "role", kind: Str, presence: false, },
      ])
    "AuthUserRevokeRoleResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
      ])
    "AuthRoleAddRequest" =>
      Some([{ number: 1, name: "name", kind: Str, presence: false, }])
    "AuthRoleAddResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
      ])
    "AuthRoleGetRequest" =>
      Some([{ number: 1, name: "role", kind: Str, presence: false, }])
    "AuthRoleGetResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
        {
          number: 2,
          name: "perm",
          kind: Rep(Message("Permission")),
          presence: false,
        },
      ])
    "AuthRoleListResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
        { number: 2, name: "roles", kind: Rep(Str), presence: false, },
      ])
    "AuthRoleDeleteRequest" =>
      Some([{ number: 1, name: "role", kind: Str, presence: false, }])
    "AuthRoleDeleteResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
      ])
    "AuthRoleGrantPermissionRequest" =>
      Some([
        { number: 1, name: "name", kind: Str, presence: false, },
        {
          number: 2,
          name: "perm",
          kind: Message("Permission"),
          presence: false,
        },
      ])
    "AuthRoleGrantPermissionResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
      ])
    "AuthRoleRevokePermissionRequest" =>
      Some([
        { number: 1, name: "role", kind: Str, presence: false, },
        { number: 2, name: "key", kind: Bytes, presence: false, },
        { number: 3, name: "range_end", kind: Bytes, presence: false, },
      ])
    "AuthRoleRevokePermissionResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
      ])
    "Permission" =>
      Some([
        {
          number: 1,
          name: "permType",
          kind: Enum(["READ", "WRITE", "READWRITE"]),
          presence: false,
        },
        { number: 2, name: "key", kind: Bytes, presence: false, },
        { number: 3, name: "range_end", kind: Bytes, presence: false, },
      ])
    "AlarmRequest" =>
      Some([
        {
          number: 1,
          name: "action",
          kind: Enum(["GET", "ACTIVATE", "DEACTIVATE"]),
          presence: false,
        },
        { number: 2, name: "memberID", kind: UInt64, presence: false, },
        {
          number: 3,
          name: "alarm",
          kind: Enum(["NONE", "NOSPACE", "CORRUPT"]),
          presence: false,
        },
      ])
    "AlarmResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
        {
          number: 2,
          name: "alarms",
          kind: Rep(Message("AlarmMember")),
          presence: false,
        },
      ])
    "AlarmMember" =>
      Some([
        { number: 1, name: "memberID", kind: UInt64, presence: false, },
        {
          number: 2,
          name: "alarm",
          kind: Enum(["NONE", "NOSPACE", "CORRUPT"]),
          presence: false,
        },
      ])
    "StatusResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
        { number: 2, name: "version", kind: Str, presence: false, },
        { number: 3, name: "dbSize", kind: Int64, presence: false, },
        { number: 4, name: "leader", kind: UInt64, presence: false, },
        { number: 5, name: "raftIndex", kind: UInt64, presence: false, },
        { number: 6, name: "raftTerm", kind: UInt64, presence: false, },
        { number: 7, name: "raftAppliedIndex", kind: UInt64, presence: false, },
        { number: 8, name: "errors", kind: Rep(Str), presence: false, },
        { number: 9, name: "dbSizeInUse", kind: Int64, presence: false, },
        { number: 10, name: "isLearner", kind: Bool, presence: false, },
      ])
    "DefragmentResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
      ])
    "HashRequest" => Some([])
    "HashResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
        { number: 2, name: "hash", kind: UInt32, presence: false, },
      ])
    "HashKVRequest" =>
      Some([{ number: 1, name: "revision", kind: Int64, presence: false, }])
    "HashKVResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
        { number: 2, name: "hash", kind: UInt32, presence: false, },
        { number: 3, name: "compact_revision", kind: Int64, presence: false, },
      ])
    "SnapshotRequest" => Some([])
    "SnapshotResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
        { number: 2, name: "remaining_bytes", kind: UInt64, presence: false, },
        { number: 3, name: "blob", kind: Bytes, presence: false, },
      ])
    "MoveLeaderRequest" =>
      Some([{ number: 1, name: "targetID", kind: UInt64, presence: false, }])
    "MoveLeaderResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
      ])
    "DowngradeRequest" =>
      Some([
        {
          number: 1,
          name: "action",
          kind: Enum(["VALIDATE", "ENABLE", "CANCEL"]),
          presence: false,
        },
        { number: 2, name: "version", kind: Str, presence: false, },
      ])
    "DowngradeResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
        { number: 2, name: "version", kind: Str, presence: false, },
      ])
    "Member" =>
      Some([
        { number: 1, name: "ID", kind: UInt64, presence: false, },
        { number: 2, name: "name", kind: Str, presence: false, },
        { number: 3, name: "peerURLs", kind: Rep(Str), presence: false, },
        { number: 4, name: "clientURLs", kind: Rep(Str), presence: false, },
        { number: 5, name: "isLearner", kind: Bool, presence: false, },
      ])
    "MemberAddRequest" =>
      Some([
        { number: 1, name: "peerURLs", kind: Rep(Str), presence: false, },
        { number: 2, name: "isLearner", kind: Bool, presence: false, },
      ])
    "MemberAddResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
        { number: 2, name: "member", kind: Message("Member"), presence: false, },
        {
          number: 3,
          name: "members",
          kind: Rep(Message("Member")),
          presence: false,
        },
      ])
    "MemberRemoveRequest" =>
      Some([{ number: 1, name: "ID", kind: UInt64, presence: false, }])
    "MemberRemoveResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
        {
          number: 2,
          name: "members",
          kind: Rep(Message("Member")),
          presence: false,
        },
      ])
    "MemberUpdateRequest" =>
      Some([
        { number: 1, name: "ID", kind: UInt64, presence: false, },
        { number: 2, name: "peerURLs", kind: Rep(Str), presence: false, },
      ])
    "MemberUpdateResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
        {
          number: 2,
          name: "members",
          kind: Rep(Message("Member")),
          presence: false,
        },
      ])
    "MemberListRequest" =>
      Some([{ number: 1, name: "linearizable", kind: Bool, presence: false, }])
    "MemberListResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
        {
          number: 2,
          name: "members",
          kind: Rep(Message("Member")),
          presence: false,
        },
      ])
    "MemberPromoteRequest" =>
      Some([{ number: 1, name: "ID", kind: UInt64, presence: false, }])
    "MemberPromoteResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
        {
          number: 2,
          name: "members",
          kind: Rep(Message("Member")),
          presence: false,
        },
      ])
    "LockRequest" =>
      Some([
        { number: 1, name: "name", kind: Bytes, presence: false, },
        { number: 2, name: "lease", kind: Int64, presence: false, },
      ])
    "LockResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
        { number: 2, name: "key", kind: Bytes, presence: false, },
      ])
    "UnlockRequest" =>
      Some([{ number: 1, name: "key", kind: Bytes, presence: false, }])
    "UnlockResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
      ])
    "CampaignRequest" =>
      Some([
        { number: 1, name: "name", kind: Bytes, presence: false, },
        { number: 2, name: "lease", kind: Int64, presence: false, },
        { number: 3, name: "value", kind: Bytes, presence: false, },
      ])
    "CampaignResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
        {
          number: 2,
          name: "leader",
          kind: Message("LeaderKey"),
          presence: false,
        },
      ])
    "LeaderKey" =>
      Some([
        { number: 1, name: "name", kind: Bytes, presence: false, },
        { number: 2, name: "key", kind: Bytes, presence: false, },
        { number: 3, name: "rev", kind: Int64, presence: false, },
        { number: 4, name: "lease", kind: Int64, presence: false, },
      ])
    "ProclaimRequest" =>
      Some([
        {
          number: 1,
          name: "leader",
          kind: Message("LeaderKey"),
          presence: false,
        },
        { number: 2, name: "value", kind: Bytes, presence: false, },
      ])
    "ProclaimResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
      ])
    "LeaderRequest" =>
      Some([{ number: 1, name: "name", kind: Bytes, presence: false, }])
    "LeaderResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
        { number: 2, name: "kv", kind: Message("KeyValue"), presence: false, },
      ])
    "ResignRequest" =>
      Some([
        {
          number: 1,
          name: "leader",
          kind: Message("LeaderKey"),
          presence: false,
        },
      ])
    "ResignResponse" =>
      Some([
        {
          number: 1,
          name: "header",
          kind: Message("ResponseHeader"),
          presence: false,
        },
      ])
    _ => None
  }
}
