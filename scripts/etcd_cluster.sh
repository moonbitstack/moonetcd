#!/usr/bin/env bash
# Three etcd members on one machine, for the integration tests that kill one.
#
#   etcd_cluster.sh up          start m1, m2 and m3 and wait for a healthy cluster
#   etcd_cluster.sh stop m1     kill a member
#   etcd_cluster.sh start m1    bring it back, with its data
#   etcd_cluster.sh down        stop everything
set -euo pipefail

root=${ETCD_CLUSTER_DIR:-/tmp/moonetcd-cluster}
initial=m1=http://127.0.0.1:2380,m2=http://127.0.0.1:22380,m3=http://127.0.0.1:32380

client_port() {
  case "$1" in m1) echo 2379 ;; m2) echo 22379 ;; m3) echo 32379 ;; esac
}

peer_port() {
  case "$1" in m1) echo 2380 ;; m2) echo 22380 ;; m3) echo 32380 ;; esac
}

member() {
  local name=$1 state=$2
  local client peer
  client=$(client_port "$name")
  peer=$(peer_port "$name")
  nohup etcd --name "$name" --data-dir "$root/$name" \
    --listen-client-urls "http://127.0.0.1:$client" --advertise-client-urls "http://127.0.0.1:$client" \
    --listen-peer-urls "http://127.0.0.1:$peer" --initial-advertise-peer-urls "http://127.0.0.1:$peer" \
    --initial-cluster "$initial" --initial-cluster-token moonetcd-it --initial-cluster-state "$state" \
    >"$root/$name.log" 2>&1 &
  echo $! >"$root/$name.pid"
}

await() {
  for _ in $(seq 1 120); do
    if etcdctl --endpoints="$1" endpoint health >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.25
  done
  echo "timed out waiting for $1" >&2
  tail -20 "$root"/*.log >&2 || true
  return 1
}

case "$1" in
  up)
    rm -rf "$root"
    mkdir -p "$root"
    for name in m1 m2 m3; do
      member "$name" new
    done
    for name in m1 m2 m3; do
      await "http://127.0.0.1:$(client_port "$name")"
    done
    ;;
  stop)
    kill -9 "$(cat "$root/$2.pid")"
    ;;
  start)
    member "$2" existing
    await "http://127.0.0.1:$(client_port "$2")"
    ;;
  down)
    for name in m1 m2 m3; do
      kill -9 "$(cat "$root/$name.pid")" 2>/dev/null || true
    done
    ;;
  *)
    echo "usage: $0 up|down|stop <member>|start <member>" >&2
    exit 2
    ;;
esac
