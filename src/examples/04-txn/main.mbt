// A transaction that swaps a counter only when it still holds the expected value,
// the compare-and-swap that Txn exists for.
//
//     moon run src/examples/04-txn

///|
async fn main {
  let config = @moonetcd.ClientConfig::{
    ..@moonetcd.default_client_config,
    endpoints: ["127.0.0.1:2379"],
  }
  let client = @client.Client::connect(config)
  let kv = client.kv()
  let _ = kv.put(b"/demo/counter", b"1")
  let cmp = @moonetcd.Compare::{
    ..@moonetcd.Compare::empty(),
    key: b"/demo/counter",
    target: @moonetcd.CompareTarget::Value,
    result: @moonetcd.CompareResult::Equal,
    target_union: @moonetcd.CmpTarget::Value(b"1"),
  }
  let yes = @moonetcd.PutRequest::{
    ..@moonetcd.PutRequest::empty(),
    key: b"/demo/counter",
    value: b"2",
  }
  let no = @moonetcd.PutRequest::{
    ..@moonetcd.PutRequest::empty(),
    key: b"/demo/counter",
    value: b"99",
  }
  let req = @moonetcd.TxnRequest::{
    compare: [cmp],
    success: [@moonetcd.RequestOp::RequestPut(yes)],
    failure: [@moonetcd.RequestOp::RequestPut(no)],
  }
  let resp = kv.txn(req)
  println("txn succeeded: \{resp.succeeded}")
  let after = kv.get(b"/demo/counter")
  for item in after.kvs {
    println("counter now = \{@utf8.decode_lossy(item.value[:])}")
  }
  let _ = kv.delete_range(@moonetcd.DeleteRangeRequest::{
    ..@moonetcd.DeleteRangeRequest::empty(),
    key: b"/demo/counter",
  })
  client.close()
}
