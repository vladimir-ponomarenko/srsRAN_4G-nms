#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_PATH="${OPEN5GS_CONFIG:-/etc/open5gs/open5gs-5gc.yaml}"
TUN_DEV="${OPEN5GS_TUN_DEV:-ogstun}"
UE_SUBNET="${OPEN5GS_UE_SUBNET:-12.1.1.0/24}"
UE_GATEWAY="${OPEN5GS_UE_GATEWAY:-12.1.1.1/24}"
MONGO_HOST="${OPEN5GS_MONGO_HOST:-mongo-5g}"

log() { printf '[open5gs-5gc] %s\n' "$*"; }

wait_for_mongo() {
  log "waiting MongoDB at ${MONGO_HOST}:27017"
  for _ in $(seq 1 120); do
    if nc -z "${MONGO_HOST}" 27017 >/dev/null 2>&1; then
      log "MongoDB is reachable"
      return 0
    fi
    sleep 1
  done
  log "MongoDB did not become reachable"
  return 1
}

setup_user_plane() {
  sysctl -w net.ipv4.ip_forward=1 >/dev/null || true
  if ! ip link show "${TUN_DEV}" >/dev/null 2>&1; then
    ip tuntap add name "${TUN_DEV}" mode tun
  fi
  ip addr flush dev "${TUN_DEV}" || true
  ip addr add "${UE_GATEWAY}" dev "${TUN_DEV}"
  ip link set "${TUN_DEV}" up

  iptables -t nat -C POSTROUTING -s "${UE_SUBNET}" -o eth0 -j MASQUERADE >/dev/null 2>&1 \
    || iptables -t nat -A POSTROUTING -s "${UE_SUBNET}" -o eth0 -j MASQUERADE
  iptables -C FORWARD -i "${TUN_DEV}" -j ACCEPT >/dev/null 2>&1 \
    || iptables -A FORWARD -i "${TUN_DEV}" -j ACCEPT
  iptables -C FORWARD -o "${TUN_DEV}" -j ACCEPT >/dev/null 2>&1 \
    || iptables -A FORWARD -o "${TUN_DEV}" -j ACCEPT
  log "user plane ready: ${TUN_DEV} ${UE_GATEWAY} NAT ${UE_SUBNET} -> eth0"
}

pids=()
start_nf() {
  nf="$1"
  bin="/usr/local/bin/open5gs-${nf}d"
  log "starting ${nf}"
  "${bin}" -c "${CONFIG_PATH}" &
  pids+=("$!")
  sleep 0.4
}

shutdown() {
  log "stopping Open5GS daemons"
  for pid in "${pids[@]:-}"; do
    kill "${pid}" >/dev/null 2>&1 || true
  done
  wait || true
}
trap shutdown TERM INT EXIT

[ -f "${CONFIG_PATH}" ] || { log "missing config: ${CONFIG_PATH}"; exit 2; }
wait_for_mongo
setup_user_plane

start_nf nrf
start_nf udr
start_nf udm
start_nf ausf
start_nf pcf
start_nf nssf
start_nf bsf
start_nf upf
start_nf smf
start_nf amf

log "all Open5GS 5GC daemons started"
while true; do
  for pid in "${pids[@]}"; do
    if ! kill -0 "${pid}" >/dev/null 2>&1; then
      log "daemon pid ${pid} exited; stopping container"
      exit 1
    fi
  done
  sleep 5
done
