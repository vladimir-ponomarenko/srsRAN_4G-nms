#!/usr/bin/env bash
set -euo pipefail

UE1_CONTAINER="${UE1_CONTAINER:-UE-1}"
UE2_CONTAINER="${UE2_CONTAINER:-UE-2}"
PING_TARGET="${PING_TARGET:-8.8.8.8}"

check_ue() {
  local ue_name="$1"
  echo
  echo "==== ${ue_name} ===="
  docker exec "${ue_name}" sh -lc 'ip -4 addr show tun_srsue || true'
  docker exec "${ue_name}" sh -lc 'ip route show'
  docker exec "${ue_name}" sh -lc "ping -c 3 -W 1 ${PING_TARGET}"
}

check_ue "${UE1_CONTAINER}"
check_ue "${UE2_CONTAINER}"

echo
echo "UE internet checks completed."
