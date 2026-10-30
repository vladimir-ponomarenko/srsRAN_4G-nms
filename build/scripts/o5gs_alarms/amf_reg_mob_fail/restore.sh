#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib.sh"
imsi="$(resolve_imsi "${1:-}")"
require_core
mongo_restore_from "${SCRIPT_DIR}/subscriber_snapshot.json" "${imsi}"
wait_for_clear amf "Alarm_O5GS_AMF_Reg_Mob_Fail" "${ALARM_WAIT:-180}"
