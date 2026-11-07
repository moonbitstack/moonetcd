#!/usr/bin/env bash
# Start and stop an etcd member that speaks TLS, with the certificates it needs written
# beside its data. Its peer port is the client port plus 5000, so two of these can run at
# once.
#
#     scripts/etcd_tls.sh up <dir> <port> [--client-cert-auth] [--certs <dir>]
#     scripts/etcd_tls.sh down <dir>
#
# The certificates land in <dir>/certs — or in the directory named by --certs, which is how
# a second member joins the first one's trust: ca.crt, server.crt, server.key, client.crt
# and client.key. A member started with --client-cert-auth asks for the last two.

set -euo pipefail

action=${1:-}
dir=${2:-}
shift 2 || true

port=23379
client_auth=""
certs=""
while [ $# -gt 0 ]; do
  case "$1" in
    --client-cert-auth) client_auth="--client-cert-auth" ;;
    --certs) certs=$2; shift ;;
    *) port=$1 ;;
  esac
  shift
done
peer_port=$((port + 5000))
[ -n "$certs" ] || certs="$dir/certs"

gen_certs() {
  [ -f "$certs/ca.crt" ] && return 0
  mkdir -p "$certs"
  openssl ecparam -name prime256v1 -genkey -noout -out "$certs/ca.key" 2>/dev/null
  openssl req -x509 -new -key "$certs/ca.key" -sha256 -days 3650 \
    -subj "/CN=moonetcd test CA" -out "$certs/ca.crt" 2>/dev/null
  openssl ecparam -name prime256v1 -genkey -noout -out "$certs/server.key" 2>/dev/null
  openssl req -new -key "$certs/server.key" -subj "/CN=localhost" \
    -out "$certs/server.csr" 2>/dev/null
  {
    printf '[ext]\n'
    printf 'subjectAltName = DNS:localhost, IP:127.0.0.1\n'
    printf 'extendedKeyUsage = serverAuth, clientAuth\n'
  } > "$certs/server.ext"
  openssl x509 -req -in "$certs/server.csr" -CA "$certs/ca.crt" -CAkey "$certs/ca.key" \
    -CAcreateserial -days 3650 -sha256 -extfile "$certs/server.ext" -extensions ext \
    -out "$certs/server.crt" 2>/dev/null
  openssl ecparam -name prime256v1 -genkey -noout -out "$certs/client.key" 2>/dev/null
  openssl req -new -key "$certs/client.key" -subj "/CN=moonetcd test client" \
    -out "$certs/client.csr" 2>/dev/null
  {
    printf '[ext]\n'
    printf 'extendedKeyUsage = clientAuth\n'
  } > "$certs/client.ext"
  openssl x509 -req -in "$certs/client.csr" -CA "$certs/ca.crt" -CAkey "$certs/ca.key" \
    -CAcreateserial -days 3650 -sha256 -extfile "$certs/client.ext" -extensions ext \
    -out "$certs/client.crt" 2>/dev/null
}

health() {
  local flags=("--cacert" "$certs/ca.crt")
  if [ "$client_auth" = "--client-cert-auth" ]; then
    flags+=("--cert" "$certs/client.crt" "--key" "$certs/client.key")
  fi
  etcdctl --endpoints "https://127.0.0.1:$port" "${flags[@]}" endpoint health \
    > /dev/null 2>&1
}

# etcd asks for a client certificate whenever it is given a CA to check one against, so the
# flags that make it do that go together: a member that does not ask for one is given none.
cert_flags=()
if [ "$client_auth" = "--client-cert-auth" ]; then
  cert_flags=("--trusted-ca-file" "$certs/ca.crt" "--client-cert-auth")
fi

case "$action" in
  up)
    gen_certs
    mkdir -p "$dir/data"
    setsid etcd \
      --name "moonetcd-tls-$port" \
      --data-dir "$dir/data" \
      --listen-client-urls "https://127.0.0.1:$port" \
      --advertise-client-urls "https://127.0.0.1:$port" \
      --listen-peer-urls "http://127.0.0.1:$peer_port" \
      --initial-advertise-peer-urls "http://127.0.0.1:$peer_port" \
      --initial-cluster "moonetcd-tls-$port=http://127.0.0.1:$peer_port" \
      --cert-file "$certs/server.crt" \
      --key-file "$certs/server.key" \
      "${cert_flags[@]}" \
      > "$dir/etcd.log" 2>&1 < /dev/null &
    echo $! > "$dir/etcd.pid"
    for _ in $(seq 1 60); do
      if health; then
        echo "etcd is up on https://127.0.0.1:$port"
        exit 0
      fi
      sleep 1
    done
    echo "etcd did not come up on https://127.0.0.1:$port" >&2
    tail -n 50 "$dir/etcd.log" >&2
    exit 1
    ;;
  down)
    if [ -f "$dir/etcd.pid" ]; then
      kill "$(cat "$dir/etcd.pid")" 2>/dev/null || true
      rm -f "$dir/etcd.pid"
    fi
    ;;
  *)
    echo "usage: $0 up|down <dir> [port] [--client-cert-auth] [--certs <dir>]" >&2
    exit 2
    ;;
esac
