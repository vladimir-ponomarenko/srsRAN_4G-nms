#!/usr/bin/env bash
# LAB/DEBUG DEMO TOOL - injects a synthetic per-NF metric view into the
# Open5GS TCA engine so a threshold-crossing alarm can be demonstrated
# deterministically. Real alarms come from REAL faults induced on the live
# stack, never from metric injection - use o5gs_alarm_scenario.sh / the
# o5gs-alarm-* make targets for that.
#
# The endpoint is served by the EMS-O5GC container on the shared open5gs-5gc
# network namespace; the port is published on the host by the open5gs-5gc
# service (see docker-compose.5g.yml "18084:18084").
#
# Usage:
#   bash build/scripts/o5gs_inject_metric.sh [host] [port] [nf] metric value
#
# Gem: the metric key must be the name the engine reads (see the rules in
# internal/ems/fcaps/o5gstca). Common ones:
#   fivegs_amffunction_rm_reginitreq  (registration denominator)
#   fivegs_amffunction_rm_reginitsucc (registration numerator)
#   fivegs_amffunction_amf_authreq / fivegs_amffunction_amf_authreject
#   fivegs_amffunction_mm_paging5greq / fivegs_amffunction_mm_paging5gsucc
#   fivegs_smffunction_sm_n4sessionestabfail
#   process_open_fds / process_max_fds
#   process_resident_memory_bytes
#
# SPDX-License-Identifier: LicenseRef-CSSL-1.0
set -euo pipefail

host=${1:-127.0.0.1}
port=${2:-18084}
nf=${3:-amf}
metric=${4:?metric key is required}
value=${5:?metric value is required}

url="http://${host}:${port}/inject"
payload=$(printf '{"nf":"%s","metrics":{"%s":%s}}' "${nf}" "${metric}" "${value}")
curl -fsS -H 'Content-Type: application/json' -d "${payload}" "${url}"
echo