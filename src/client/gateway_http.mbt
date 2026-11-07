// One HTTP/1.1 connection to an etcd endpoint, for the gateway transport. The
// protocol is the sans-IO state machine in `moonhttp/http1`; this file feeds it
// octets from a TCP socket and writes back what it asks for, so a streamed reply is
// parsed as it arrives rather than read to the end first.

///|
/// A connection to one endpoint, with the request in flight or the last one finished.
pub struct HttpConn {
  socket : @tcp.Conn
  http : @http1.Conn
  authority : String
  mut reusable : Bool
}

///|
/// Dial `host:port` and start an HTTP/1.1 client on it. With `tls` the socket is
/// upgraded before the first request.
pub async fn HttpConn::open(
  host : String,
  port : Int32,
  tls? : @tls.Client,
) -> HttpConn raise EtcdError {
  let socket = @tcp.dial(host, port~) catch {
    _ => raise transport_error("gateway dial " + host + ":" + port.to_string())
  }
  let socket = match tls {
    None => socket
    Some(client) => {
      // The connection is named by the address it dials; what the certificate has to say
      // is `server_name`, and that is the judge's business, not the handshake's.
      let upgraded = socket.upgrade(client, host) catch {
        _ => {
          socket.close()
          raise transport_error(
            "gateway tls handshake " + host + ":" + port.to_string(),
          )
        }
      }
      // etcd's gateway is HTTP/1.1, and its secure port would have spoken HTTP/2 had
      // the handshake agreed to it; a connection that did is not one to write a
      // request line on.
      if upgraded.alpn() == Some(@net.alpn_h2) {
        upgraded.close()
        raise transport_error("gateway tls settled on " + @net.alpn_h2)
      }
      upgraded
    }
  }
  {
    socket,
    http: @http1.Conn::new(@http1.Client),
    authority: host + ":" + port.to_string(),
    reusable: true,
  }
}

///|
/// Post `body` to `path`, with the gateway's headers plus whatever metadata the call
/// carries. The gateway reads the auth token from `Authorization`, which is where the
/// `token` metadata goes.
pub async fn HttpConn::post(
  self : HttpConn,
  path : String,
  body : Bytes,
  metadata : Array[@header.Header],
) -> Unit raise EtcdError {
  let fields : Array[@header.Header] = [
    @header.Header::of("content-type", "application/json"),
  ]
  for header in metadata {
    let (name, value) = header.ascii()
    if name == "token" {
      fields.push(@header.Header::of("authorization", value))
    } else {
      fields.push(header)
    }
  }
  let request = @http1.Request::of(
    "POST",
    path,
    fields~,
    body=@http1.Sized(body.length()),
    host=self.authority,
  )
  let head = self.http.send(@http1.Event::Request(request)) catch {
    _ => raise transport_error("gateway request head")
  }
  self.write(head)
  if body.length() > 0 {
    let payload = self.http.send(@http1.Event::Data(body)) catch {
      _ => raise transport_error("gateway request body")
    }
    self.write(payload)
  }
  let end = self.http.send(@http1.Event::End([])) catch {
    _ => raise transport_error("gateway request end")
  }
  if end.length() > 0 {
    self.write(end)
  }
}

///|
/// Put octets on the socket, with a socket failure turned into the same error a
/// dropped connection reports.
async fn HttpConn::write(self : HttpConn, data : Bytes) -> Unit raise EtcdError {
  self.socket.write(data) catch {
    _ => raise transport_error("gateway write")
  }
}

///|
/// The next octets the peer sent, or `None` when it hung up.
async fn HttpConn::read(self : HttpConn) -> Bytes? raise EtcdError {
  self.socket.read_some(max_len=16384) catch {
    _ => raise transport_error("gateway read")
  }
}

///|
/// The next event the peer sends, with more octets read from the socket whenever the
/// state machine asks for them. `Closed` means the peer hung up.
pub async fn HttpConn::next_event(
  self : HttpConn,
) -> @http1.Event raise EtcdError {
  for ;; {
    let event = self.http.next() catch {
      _ => raise transport_error("gateway reply")
    }
    match event {
      NeedData => {
        let more = self.read()
        match more {
          Some(data) =>
            self.http.receive(data[:]) catch {
              _ => raise transport_error("gateway reply")
            }
          None => return @http1.Closed
        }
      }
      other => return other
    }
  }
}

///|
/// The status line and headers of the reply, as soon as they have arrived.
pub async fn HttpConn::response_head(
  self : HttpConn,
) -> @http1.Response raise EtcdError {
  for ;; {
    match self.next_event() {
      Response(response) => return response
      Informational(_) => continue
      Closed => raise transport_error("gateway closed before replying")
      _ => raise transport_error("gateway reply is not a response")
    }
  }
}

///|
/// The rest of the body, up to the end of the message.
pub async fn HttpConn::body(self : HttpConn) -> Bytes raise EtcdError {
  let buffer = @buffer.Buffer()
  for ;; {
    match self.next_event() {
      Data(data) => buffer.write_bytes(data)
      End(_) => {
        // A message that ended cleanly leaves the connection reusable.
        self.reusable = true
        return buffer.to_bytes()
      }
      Closed => {
        self.reusable = false
        return buffer.to_bytes()
      }
      _ => ()
    }
  }
}

///|
/// Drop the connection. A stream holds its own, so this is how a watch a caller has
/// lost interest in is cancelled: the gateway cancels the watch when the request ends.
pub fn HttpConn::close(self : HttpConn) -> Unit {
  self.reusable = false
  self.socket.close()
}

///|
/// Whether the connection can carry another request.
pub fn HttpConn::is_reusable(self : HttpConn) -> Bool {
  self.reusable &&
  self.http.ours() is @http1.Done &&
  self.http.theirs() is @http1.Done
}

///|
/// Begin the next exchange on a kept-alive connection.
pub fn HttpConn::ready(self : HttpConn) -> Unit raise EtcdError {
  self.http.start_next() catch {
    _ => raise transport_error("gateway connection cannot be reused")
  }
}
