#!/usr/bin/env bash
set -euo pipefail

serial="${1:-}"
if [[ -z "${serial}" ]]; then
  echo "Usage: $0 <enb_serial>" >&2
  exit 2
fi

endpoints=(
  "${EMS_CONTROL_URL_ENB1:-http://127.0.0.1:18081}"
  "${EMS_CONTROL_URL_ENB2:-http://127.0.0.1:18082}"
)

payload=$(printf '{"serial":"%s"}' "${serial}")

for base in "${endpoints[@]}"; do
  url="${base%/}/v1/control/restart"
  echo "[control] trying ${url}"
  set +e
  resp=$(curl -sS -m 20 -X POST \
    -H "Content-Type: application/json" \
    --data "${payload}" \
    "${url}")
  rc=$?
  set -e
  if [[ ${rc} -ne 0 ]]; then
    echo "[control] request failed at ${url}" >&2
    continue
  fi
  echo "${resp}"
  if command -v rg >/dev/null 2>&1; then
    if echo "${resp}" | rg -q '"status"\s*:\s*"(ok|accepted)"'; then
      echo "[control] restart request accepted by ${base}"
      exit 0
    fi
  elif echo "${resp}" | grep -Eq '"status"[[:space:]]*:[[:space:]]*"(ok|accepted)"'; then
    echo "[control] restart request accepted by ${base}"
    exit 0
  fi
done

echo "[control] no EMS instance accepted restart for serial: ${serial}" >&2
exit 1
