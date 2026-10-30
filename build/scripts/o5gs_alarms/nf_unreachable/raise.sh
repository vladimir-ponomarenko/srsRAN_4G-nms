#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib.sh"
nf="${ALARM_NF:-amf}"
ALARM_NF="${nf}"
alarm_raise nf_unreachable
