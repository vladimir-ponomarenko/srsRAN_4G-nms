#!/usr/bin/env bash
set -Eeuo pipefail

UE_CONTAINER="${UE_CONTAINER:-5G-OAI-NR-UE}"
SERVER_IP="${SERVER_IP:-10.55.0.50}"
MODE="${1:-dl}"
DURATION="${IPERF_DURATION:-10}"

ue_if="$(docker exec "$UE_CONTAINER" sh -lc "ip -o link show | awk -F': ' '/oaitun|uesimtun|tun/{print \$2; exit}'")"
if [ -z "$ue_if" ]; then
  echo "UE tunnel interface not found in ${UE_CONTAINER}" >&2
  exit 1
fi

docker exec "$UE_CONTAINER" ip route replace "${SERVER_IP}/32" via 12.1.1.1 dev "$ue_if" || true
ue_ip="$(docker exec "$UE_CONTAINER" sh -lc "ip -4 -o addr show dev '$ue_if' | awk '{sub(/\\/.*$/,\"\",\$4); print \$4; exit}'")"

case "$MODE" in
  dl|downlink)
    docker exec "$UE_CONTAINER" iperf3 -c "$SERVER_IP" -B "$ue_ip" -t "$DURATION" -R
    ;;
  ul|uplink)
    docker exec "$UE_CONTAINER" iperf3 -c "$SERVER_IP" -B "$ue_ip" -t "$DURATION"
    ;;
  *)
    echo "Usage: $0 [dl|ul]" >&2
    exit 2
    ;;
esac
