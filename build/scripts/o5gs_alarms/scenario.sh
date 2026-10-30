#!/usr/bin/env bash
# Induces REAL Open5GS 5GC faults on the live stack 
#
# Usage:
#   o5gs_alarm_scenario.sh nf-down   <amf|smf|upf|pcf|nrf|...>   # SIGSTOP one NF
#   o5gs_alarm_scenario.sh nf-up     <amf|smf|upf|pcf|nrf|...>   # SIGCONT one NF
#   o5gs_alarm_scenario.sh multi-down [nf...]                    # halt several (default amf smf upf pcf)
#   o5gs_alarm_scenario.sh multi-up   [nf...]                    # resume several
#   o5gs_alarm_scenario.sh all-down                              # halt amf smf upf pcf
#   o5gs_alarm_scenario.sh all-up                                # resume amf smf upf pcf
#   o5gs_alarm_scenario.sh gnb-down                              # docker stop 5G-OAI-GNB
#   o5gs_alarm_scenario.sh gnb-up                                # docker start 5G-OAI-GNB
#
# SPDX-License-Identifier: LicenseRef-CSSL-1.0
set -euo pipefail

core_container=${OPEN5GS_CORE_CONTAINER:-5G-OPEN5GS}
gnb_container=${OPEN5GS_GNB_CONTAINER:-5G-OAI-GNB}

# Network function -> open5gs daemon binary/process name.
nf_daemon() {
  case "$1" in
    nrf) echo open5gs-nrfd ;;
    udr) echo open5gs-udrd ;;
    udm) echo open5gs-udmd ;;
    ausf) echo open5gs-ausfd ;;
    pcf) echo open5gs-pcfd ;;
    nssf) echo open5gs-nssfd ;;
    bsf) echo open5gs-bsfd ;;
    upf) echo open5gs-upfd ;;
    smf) echo open5gs-smfd ;;
    amf) echo open5gs-amfd ;;
    *) echo "" ;;
  esac
}

ci_signal() {
  # ci_signal <nf> <STOP|CONT>
  local nf="$1" sig="$2"
  local daemon
  daemon="$(nf_daemon "$nf")"
  if [ -z "$daemon" ]; then
    echo "unknown NF: $nf (valid: nrf udr udm ausf pcf nssf bsf upf smf amf)" >&2
    exit 2
  fi
  if ! docker ps --format '{{.Names}}' | grep -qx "${core_container}"; then
    echo "core container not running: ${core_container}" >&2
    exit 1
  fi
  local pids
  pids="$(docker exec "${core_container}" sh -c "pgrep -x '${daemon}' || true")"
  if [ -z "$pids" ]; then
    echo "no running ${daemon} process found (is the NF up?)" >&2
    exit 1
  fi
  for pid in $pids; do
    docker exec "${core_container}" sh -c "kill -${sig} ${pid}"
    echo "sent SIG${sig} to ${daemon} (pid ${pid})"
  done
}

case "${1:-}" in
  nf-down)
    [ $# -ge 2 ] || { echo "usage: $0 nf-down <nf>" >&2; exit 2; }
    ci_signal "$2" STOP
    ;;
  nf-up)
    [ $# -ge 2 ] || { echo "usage: $0 nf-up <nf>" >&2; exit 2; }
    ci_signal "$2" CONT
    ;;
  multi-down|multi-up)
    sig=CONT; [ "${1}" = multi-down ] && sig=STOP
    shift
    nfs=("$@")
    [ ${#nfs[@]} -gt 0 ] || nfs=(amf smf upf pcf)
    for nf in "${nfs[@]}"; do
      ci_signal "$nf" "$sig"
    done
    ;;
  all-down)
    for nf in amf smf upf pcf; do ci_signal "$nf" STOP; done
    ;;
  all-up)
    for nf in amf smf upf pcf; do ci_signal "$nf" CONT; done
    ;;
  gnb-down)
    docker stop "${gnb_container}"
    ;;
  gnb-up)
    docker start "${gnb_container}"
    ;;
  *)
    echo "usage: $0 {nf-down|nf-up|multi-down|multi-up|all-down|all-up|gnb-down|gnb-up} [nf...]" >&2
    exit 2
    ;;
esac