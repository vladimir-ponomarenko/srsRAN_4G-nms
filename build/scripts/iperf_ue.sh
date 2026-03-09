#!/usr/bin/env bash
set -euo pipefail

UE_NAME="${1:-}"
MODE="${2:-}"
DURATION="${DURATION:-10}"
PARALLEL="${PARALLEL:-1}"
PORT="${PORT:-5201}"
EPC_IP="${EPC_IP:-172.16.0.1}"
EPC_CONTAINER="${EPC_CONTAINER:-EPC}"

if [[ -z "${UE_NAME}" || -z "${MODE}" ]]; then
  echo "Usage: iperf_ue.sh <UE-1|UE-2> <dl|ul>" >&2
  exit 2
fi

if ! docker ps --format '{{.Names}}' | grep -qx "${UE_NAME}"; then
  echo "Container ${UE_NAME} is not running." >&2
  exit 1
fi
if ! docker ps --format '{{.Names}}' | grep -qx "${EPC_CONTAINER}"; then
  echo "Container ${EPC_CONTAINER} is not running." >&2
  exit 1
fi

docker exec "${EPC_CONTAINER}" sh -lc "iperf3 -s -1 -p ${PORT} >/tmp/iperf3_${PORT}.log 2>&1 &"
for i in $(seq 1 20); do
  if docker exec "${EPC_CONTAINER}" sh -lc "ss -ltn | grep -q ':${PORT}'"; then
    break
  fi
  sleep 0.2
done

run_client() {
  local cmd="$1"
  for i in $(seq 1 3); do
    if docker exec "${UE_NAME}" sh -lc "${cmd}"; then
      return 0
    fi
    sleep 0.5
  done
  return 1
}

if [[ "${MODE}" == "dl" ]]; then
  run_client "iperf3 -c ${EPC_IP} -R -t ${DURATION} -P ${PARALLEL} -p ${PORT}"
elif [[ "${MODE}" == "ul" ]]; then
  run_client "iperf3 -c ${EPC_IP} -t ${DURATION} -P ${PARALLEL} -p ${PORT}"
else
  echo "Invalid mode: ${MODE}. Use dl or ul." >&2
  exit 2
fi
