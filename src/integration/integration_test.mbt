// Integration tests against a live etcd, by default at 127.0.0.1:2379 (see `live_test`).
// `try_connect` probes the
// member and returns `None` when nothing answers, so these tests are a no-op on a machine
// without etcd; with `MOONETCD_LIVE` set, as in CI, a missing server fails them. Every test
// uses its own key prefix so runs do not collide.
//
// These cover KV, Txn, Lease, Watch, Cluster, Auth, Maintenance and the v3election
// service against a real etcd, which is where wire field-number mistakes surface.

///|
async fn try_connect() -> @client.Client? {
  let c = @client.Client::connect(live_config())
  let up = try {
    let _ = c.maintenance().status()
    true
  } catch {
    _ => false
  }
  if up {
    Some(c)
  } else {
    c.close()
    if live_required() {
      fail(live_missing())
    }
    None
  }
}

///|
async test "integration: kv put / get / prefix / delete" {
  match try_connect() {
    None => ()
    Some(c) => {
      let kv = c.kv()
      let _ = kv.put(b"/moonetcd-it/kv/a", b"alpha")
      let _ = kv.put(b"/moonetcd-it/kv/b", b"beta")
      let one = kv.get(b"/moonetcd-it/kv/a")
      assert_eq(one.kvs.length(), 1)
      assert_eq(one.kvs[0].value, b"alpha")
      let pref = kv.get_prefix(b"/moonetcd-it/kv/")
      assert_eq(pref.count >= 2L, true)
      let del = kv.delete_range(@moonetcd.DeleteRangeRequest::{
        ..@moonetcd.DeleteRangeRequest::empty(),
        key: b"/moonetcd-it/kv/",
        range_end: @moonetcd.prefix(b"/moonetcd-it/kv/"),
      })
      assert_eq(del.deleted >= 2L, true)
      c.close()
    }
  }
}

///|
async test "integration: txn compare-and-swap" {
  match try_connect() {
    None => ()
    Some(c) => {
      let kv = c.kv()
      let _ = kv.put(b"/moonetcd-it/txn", b"1")
      let cmp = @moonetcd.Compare::{
        ..@moonetcd.Compare::empty(),
        key: b"/moonetcd-it/txn",
        target: @moonetcd.CompareTarget::Value,
        result: @moonetcd.CompareResult::Equal,
        target_union: @moonetcd.CmpTarget::Value(b"1"),
      }
      let yes = @moonetcd.PutRequest::{
        ..@moonetcd.PutRequest::empty(),
        key: b"/moonetcd-it/txn",
        value: b"2",
      }
      let no = @moonetcd.PutRequest::{
        ..@moonetcd.PutRequest::empty(),
        key: b"/moonetcd-it/txn",
        value: b"99",
      }
      let resp = kv.txn(@moonetcd.TxnRequest::{
        compare: [cmp],
        success: [@moonetcd.RequestOp::RequestPut(yes)],
        failure: [@moonetcd.RequestOp::RequestPut(no)],
      })
      assert_eq(resp.succeeded, true)
      let after = kv.get(b"/moonetcd-it/txn")
      assert_eq(after.kvs[0].value, b"2")
      let _ = kv.delete_range(@moonetcd.DeleteRangeRequest::{
        ..@moonetcd.DeleteRangeRequest::empty(),
        key: b"/moonetcd-it/txn",
      })
      c.close()
    }
  }
}

///|
async test "integration: lease grant / time-to-live / revoke" {
  match try_connect() {
    None => ()
    Some(c) => {
      let lease = c.lease()
      let granted = lease.grant(30L)
      assert_eq(granted.ttl >= 1L, true)
      let _ = c.kv().put(b"/moonetcd-it/leased", b"x", lease=granted.id)
      let ttl = lease.time_to_live(granted.id, keys=true)
      assert_eq(ttl.keys.length() >= 1, true)
      let _ = lease.revoke(granted.id)
      let gone = c.kv().get(b"/moonetcd-it/leased")
      assert_eq(gone.kvs.length(), 0)
      c.close()
    }
  }
}

///|
async test "integration: cluster member list" {
  match try_connect() {
    None => ()
    Some(c) => {
      let resp = c.cluster().member_list()
      assert_eq(resp.members.length() >= 1, true)
      c.close()
    }
  }
}

///|
async test "integration: auth status on a fresh member" {
  match try_connect() {
    None => ()
    Some(c) => {
      let st = c.auth().status()
      assert_eq(st.enabled, false)
      c.close()
    }
  }
}

///|
async test "integration: maintenance alarm get is empty on a fresh member" {
  match try_connect() {
    None => ()
    Some(c) => {
      let resp = c
        .maintenance()
        .alarm(@moonetcd.AlarmAction::Get, 0UL, @moonetcd.AlarmType::None)
      assert_eq(resp.alarms.length(), 0)
      c.close()
    }
  }
}

///|
async test "integration: election campaign / leader / resign" {
  match try_connect() {
    None => ()
    Some(c) => {
      let granted = c.lease().grant(30L)
      let name = b"/moonetcd-it/election"
      let camp = c.election().campaign(name, b"candidate", granted.id)
      assert_eq(camp.leader.name, name)
      let lead = c.election().leader(name)
      assert_eq(lead.kv.key.length() >= 1, true)
      let _ = c.election().resign(camp.leader)
      let _ = c.lease().revoke(granted.id)
      c.close()
    }
  }
}

///|
async test "integration: watch sees a put" {
  match try_connect() {
    None => ()
    Some(c) => {
      @async.with_task_group <| g => {
        let req = @moonetcd.WatchCreateRequest::{
          ..@moonetcd.WatchCreateRequest::empty(),
          key: b"/moonetcd-it/watch",
        }
        let chan = c.watch().watch_create(g, req)
        // Wait for the create acknowledgement, so the put below is observed rather
        // than racing ahead of the watch's registration.
        let _ = chan.next()
        let _ = c.kv().put(b"/moonetcd-it/watch", b"changed")
        let mut events = 0
        let mut reads = 0
        while reads < 5 && events == 0 {
          match chan.next() {
            Some(resp) => {
              events = events + resp.events.length()
              reads = reads + 1
            }
            None => reads = 5
          }
        }
        assert_eq(events >= 1, true)
        chan.cancel()
        let _ = c
          .kv()
          .delete_range(@moonetcd.DeleteRangeRequest::{
            ..@moonetcd.DeleteRangeRequest::empty(),
            key: b"/moonetcd-it/watch",
          })
      }
      c.close()
    }
  }
}
