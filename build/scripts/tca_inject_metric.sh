#!/usr/bin/env bash
set -euo pipefail

host=${1:-127.0.0.1}
port=${2:-18081}
managed_object=${3:-"SubNetwork=srsRAN/ManagedElement=enb1/ENBFunction=1"}
metric=${4:?metric key is required}
value=${5:?metric value is required}
repeat=${6:-1}
delay=${7:-1}

url="http://${host}:${port}/v1/control/fm/tca/test-report"

for i in $(seq 1 "${repeat}"); do
  payload=$(printf '{"managed_object":"%s","metrics":{"%s":%s}}' "${managed_object}" "${metric}" "${value}")
  curl -fsS -H 'Content-Type: application/json' -d "${payload}" "${url}"
  echo
  if [ "${i}" -lt "${repeat}" ]; then
    sleep "${delay}"
  fi
done
