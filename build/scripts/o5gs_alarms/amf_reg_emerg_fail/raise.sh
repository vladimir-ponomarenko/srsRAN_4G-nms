#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib.sh"
imsi="$(resolve_imsi "${1:-}")"
require_core
mongo_snapshot_to "${SCRIPT_DIR}/subscriber_snapshot.json" "${imsi}"
alarm_raise amf_reg_emerg_fail "${imsi}"
