// The gateway transport against a stand-in HTTP/1.1 server — no etcd needed. The
// reply is written in two pieces so the transport has to put it back together, which
// is the part a real server exercises only when a frame is larger than a socket read.

///|
/// The `Content-Length` of a request head, or 0.
fn content_length(head : String) -> Int32 {
  let text = head.to_lower()
  match text.find("content-length:") {
    None => 0
    Some(at) => {
      let rest = text[at + 15:].to_owned()
      let chars = rest.to_array()
      let mut value = 0
      for i = 0; i < chars.length(); i = i + 1 {
        let digit = chars[i].to_int()
        if digit >= 48 && digit <= 57 {
          value = value * 10 + (digit - 48)
        } else if value > 0 {
          break
        }
      }
      value
    }
  }
}

///|
/// Answer one Range request with a fixed body, written in two pieces so it arrives in
/// more than one read.
async fn serve_range(listener : @tcp.Listener) -> Unit {
  let (conn, _) = listener.accept()
  let head = conn.read_until("\r\n\r\n") catch { _ => None }
  match head {
    None => conn.close()
    Some(head) => {
      let wanted = content_length(head)
      if wanted > 0 {
        let _ = conn.read_exactly(wanted) catch { _ => b"" }
      }
      let body =
        #|{"header":{"cluster_id":"1","member_id":"2","revision":"5","raft_term":"1"},"kvs":[{"key":"Z3JlZXRpbmc=","create_revision":"5","mod_revision":"5","version":"1","value":"aGVsbG8="}],"count":"1"}
      let reply = "HTTP/1.1 200 OK\r\ncontent-type: application/json\r\ncontent-length: " +
        body.length().to_string() +
        "\r\n\r\n" +
        body
      let cut = reply.length() / 2
      conn.write(reply[:cut].to_owned())
      @async.sleep(20)
      conn.write(reply[cut:].to_owned())
      conn.close()
    }
  }
}

///|
async test "gateway transport: a reply that arrives in pieces is reassembled" {
  @async.with_task_group <| g => {
    let listener = @tcp.listen(host="127.0.0.1", port=0)
    let port = listener.addr().port()
    let _ = g.spawn(() => serve_range(listener))
    let client = Client::connect_gateway(@moonetcd.ClientConfig::{
      ..@moonetcd.default_client_config,
      endpoints: ["127.0.0.1:\{port}"],
    })
    let response = client.kv().get(b"greeting")
    assert_eq(response.count, 1L)
    assert_eq(response.kvs.length(), 1)
    // The key came back as base64, which is how the gateway carries bytes.
    assert_eq(response.kvs[0].key, b"greeting")
    assert_eq(response.kvs[0].value, b"hello")
    assert_eq(response.header.revision, 5L)
    client.close()
  }
}

///|
/// A chunked reply carrying one JSON frame, newline-terminated as the gateway writes
/// them. No last chunk, so the message ends when the connection does — which is how a
/// watch stream ends.
fn chunked_reply(frame : String) -> String {
  let piece = frame + "\n"
  "HTTP/1.1 200 OK\r\ntransfer-encoding: chunked\r\n\r\n" +
  piece.length().to_string(radix=16) +
  "\r\n" +
  piece +
  "\r\n"
}

///|
/// Two connections: the first acknowledges the create and then drops, the second
/// resumes from the revision the create asks for and delivers the event.
async fn serve_watch_twice(
  listener : @tcp.Listener,
  resumed : Array[String],
) -> Unit {
  let create =
    #|{"result":{"header":{"revision":"1"},"created":true,"watch_id":"0"}}
  let event =
    #|{"result":{"header":{"revision":"2"},"watch_id":"0","events":[{"type":"PUT","kv":{"key":"Z3JlZXRpbmc=","create_revision":"2","mod_revision":"2","version":"1","value":"aGVsbG8="}}]}}
  for round = 0; round < 2; round = round + 1 {
    let (conn, _) = listener.accept()
    let head = conn.read_until("\r\n\r\n") catch { _ => None }
    match head {
      None => conn.close()
      Some(head) => {
        let wanted = content_length(head)
        if wanted > 0 {
          let body = conn.read_exactly(wanted) catch { _ => b"" }
          if round == 1 {
            resumed.push(@utf8.decode_lossy(body[:]))
          }
        }
        let reply = chunked_reply(if round == 0 { create } else { event })
        conn.write(reply)
        conn.close()
      }
    }
  }
}

///|
async test "gateway transport: a watch resumes from the last revision after a drop" {
  @async.with_task_group <| g => {
    let listener = @tcp.listen(host="127.0.0.1", port=0)
    let port = listener.addr().port()
    let resumed : Array[String] = []
    let _ = g.spawn(() => serve_watch_twice(listener, resumed))
    let client = Client::connect_gateway(@moonetcd.ClientConfig::{
      ..@moonetcd.default_client_config,
      endpoints: ["127.0.0.1:\{port}"],
    })
    let chan = client
      .watch()
      .watch_create(g, @moonetcd.WatchCreateRequest::{
        ..@moonetcd.WatchCreateRequest::empty(),
        key: b"greeting",
      })
    let created = chan.next()
    assert_eq(created.unwrap().created, true)
    // The connection ended after the acknowledgement; the next read has to reissue the
    // create past revision 1 and deliver what the second connection sends.
    let event = chan.next()
    let response = event.unwrap()
    assert_eq(response.events.length(), 1)
    assert_eq(response.events[0].kv.value, b"hello")
    assert_eq(resumed.length(), 1)
    assert_true(resumed[0].contains("\"start_revision\":\"2\""))
    chan.cancel()
    client.close()
  }
}
