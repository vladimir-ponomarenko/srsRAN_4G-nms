#!/usr/bin/env bash
set -euo pipefail

UE_CONF_PATH="${1:-/etc/srsran/ue.conf}"
EPC_GW_IP="${EPC_GW_IP:-172.16.0.1}"
UE_TUN_DEV="${UE_TUN_DEV:-tun_srsue}"
WAIT_TIMEOUT_SEC="${UE_TUN_WAIT_TIMEOUT_SEC:-120}"

on_term() {
  if [[ -n "${UE_PID:-}" ]] && kill -0 "${UE_PID}" 2>/dev/null; then
    kill -TERM "${UE_PID}" 2>/dev/null || true
    wait "${UE_PID}" || true
  fi
  exit 0
}

trap on_term INT TERM

echo "--- Starting srsUE (${UE_CONF_PATH}) ---"
srsue "${UE_CONF_PATH}" &
UE_PID=$!

echo "--- Waiting for UE tunnel ${UE_TUN_DEV} (timeout: ${WAIT_TIMEOUT_SEC}s) ---"
for ((i=1; i<=WAIT_TIMEOUT_SEC; i++)); do
  if ip link show "${UE_TUN_DEV}" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! ip link show "${UE_TUN_DEV}" >/dev/null 2>&1; then
  echo "WARNING: ${UE_TUN_DEV} was not created in ${WAIT_TIMEOUT_SEC}s. Keeping current routes."
  wait "${UE_PID}"
  exit $?
fi

for ((i=1; i<=WAIT_TIMEOUT_SEC; i++)); do
  if ip -4 addr show "${UE_TUN_DEV}" | grep -q "inet "; then
    break
  fi
  sleep 1
done

if ip -4 addr show "${UE_TUN_DEV}" | grep -q "inet "; then
  echo "--- Configuring UE default route via EPC ${EPC_GW_IP} dev ${UE_TUN_DEV} ---"
  ip route replace default via "${EPC_GW_IP}" dev "${UE_TUN_DEV}" || true
  ip route show
else
  echo "WARNING: ${UE_TUN_DEV} has no IPv4 address yet. Default route unchanged."
fi

wait "${UE_PID}"
