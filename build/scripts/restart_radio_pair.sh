#!/usr/bin/env bash
set -euo pipefail

pair="${1:-}"
if [[ -z "${pair}" ]]; then
  echo "Usage: restart_radio_pair.sh <1|2>" >&2
  exit 2
fi

case "${pair}" in
  1)
    enb_service="srsenb-1"
    ue_service="srsue"
    ;;
  2)
    enb_service="srsenb-2"
    ue_service="srsue-2"
    ;;
  *)
    echo "Invalid pair: ${pair}. Use 1 or 2." >&2
    exit 2
    ;;
esac

echo "[radio] hard reset pair ${pair}: ${enb_service} + ${ue_service}"
docker compose stop "${ue_service}" "${enb_service}" || true
docker compose rm -f "${ue_service}" "${enb_service}" || true
docker compose up -d "${enb_service}"

for i in $(seq 1 30); do
  if docker compose ps --status running --services | grep -qx "${enb_service}"; then
    break
  fi
  sleep 1
done

sleep 5

docker compose up -d "${ue_service}"
echo "[radio] pair ${pair} restarted"
