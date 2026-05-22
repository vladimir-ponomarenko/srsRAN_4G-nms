#!/usr/bin/env bash
set -Eeuo pipefail

UE_CONTAINER="${UE_CONTAINER:-5G-OAI-NR-UE}"
PING_TARGET="${PING_TARGET:-8.8.8.8}"
TIMEOUT_SEC="${TIMEOUT_SEC:-180}"
INTERVAL_SEC="${INTERVAL_SEC:-3}"

log() { printf '[5g-check] %s\n' "$*"; }

find_ue_if() {
  docker exec "$UE_CONTAINER" sh -lc "ip -o link show | awk -F': ' '/oaitun|uesimtun|tun/{print \$2; exit}'" 2>/dev/null || true
}

start_ts=$(date +%s)
while true; do
  ifname="$(find_ue_if)"
  if [ -n "$ifname" ]; then
    addr="$(docker exec "$UE_CONTAINER" sh -lc "ip -4 -o addr show dev '$ifname' | awk '{print \$4; exit}'" 2>/dev/null || true)"
    if [ -n "$addr" ]; then
      log "UE data interface is up: ${ifname} ${addr}"
      if docker exec "$UE_CONTAINER" ping -I "$ifname" -c 3 -W 3 "$PING_TARGET"; then
        log "internet ping via ${ifname} succeeded"
        exit 0
      fi
      log "interface exists but ping failed; waiting"
    fi
  else
    log "waiting for UE tunnel interface"
  fi

  now=$(date +%s)
  if [ $((now - start_ts)) -ge "$TIMEOUT_SEC" ]; then
    log "timeout waiting for 5G UE connectivity"
    docker compose -f docker-compose.5g.yml ps || true
    docker compose -f docker-compose.5g.yml logs --tail=80 oai-nr-ue oai-gnb open5gs-5gc || true
    exit 1
  fi
  sleep "$INTERVAL_SEC"
done
