#!/usr/bin/env bash
set -euo pipefail

container=${1:-ENB-1}
message=${2:-"S1 Setup failed: unknown PLMN"}
path=${3:-}

case "${container}" in
  ENB-1|srsenb-1)
    path=${path:-/var/run/enb-metrics/enb1_alarms.log}
    ;;
  ENB-2|srsenb-2)
    path=${path:-/var/run/enb-metrics/enb2_alarms.log}
    ;;
  *)
    if [ -z "${path}" ]; then
      echo "usage: $0 <ENB-1|ENB-2|container> <message> <alarm-log-path>" >&2
      exit 2
    fi
    ;;
esac

if ! docker ps --format '{{.Names}}' | grep -qx "${container}"; then
  echo "container not running: ${container}" >&2
  exit 1
fi

docker exec -i \
  -e FM_ALARM_MESSAGE="${message}" \
  -e FM_ALARM_PATH="${path}" \
  "${container}" sh -c 'mkdir -p "$(dirname "$FM_ALARM_PATH")" && printf "%s\n" "$FM_ALARM_MESSAGE" >> "$FM_ALARM_PATH"'

echo "[fm] appended to ${container}:${path}: ${message}"
