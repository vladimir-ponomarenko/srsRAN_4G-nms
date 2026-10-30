#!/usr/bin/env bash
# Shared library for the per-alarm Open5GS scenarios.
#
# 	* build/scripts/o5gs_alarms/<alarm>/raise.sh    - induce a REAL fault
# 	  (process SIGSTOP, gNB stop, iptables N4/N3 drop, subscriber-DB edit) so
# 	  the engine's real scraped counters move, then wait for the alarm.
# 	* build/scripts/o5gs_alarms/<alarm>/restore.sh  - undo EXACTLY the fault
# 	  and confirm the alarm is CLEARED.
#
# SPDX-License-Identifier: LicenseRef-CSSL-1.0
set -euo pipefail

# This library draws in SCRIPT_DIR from the CALLING <alarm>/raise.sh (the
# per-alarm directory) so snapshots live next to each scenario. Only ALARM_DIR
# (this library's directory) and REPO_ROOT are defined here.
ALARM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${ALARM_DIR}/../../.." && pwd)"
LOG_DIR="${REPO_ROOT}/logs"
LOG_FILE="${LOG_DIR}/o5gs-alarms-$(date +%Y%m%d).log"
mkdir -p "${LOG_DIR}"

core_container=${OPEN5GS_CORE_CONTAINER:-5G-OPEN5GS}
gnb_container=${OPEN5GS_GNB_CONTAINER:-5G-OAI-GNB}
ue_container=${OPEN5GS_UE_CONTAINER:-5G-OAI-NR-UE}
mongo_container=${OPEN5GS_MONGO_CONTAINER:-5G-MONGO}
ems_container=${OPEN5GS_EMS_CONTAINER:-EMS-O5GC}
mongo_db=${OPEN5GS_MONGO_DB:-open5gs}
poll_script="${REPO_ROOT}/build/scripts/open5gs_metrics_poll.sh"

# ---------------------------------------------------------------------------
# Scenario defaults. Every `<alarm>/raise.sh|restore.sh` runs out-of-the-box
# with no parameters:
#   * DEFAULT_SUBSCRIBER_IMSI - the subscriber the subscriber-DB fault scenarios
#     operate on when none is given (seeded in config/open5gs5g/mongo-init.js and
#     matching config/oai5g/nr-ue.yaml; override with SUBSCRIBER_IMSI or argv).
#   * DEFAULT_ALARM_NF        - NF the NF-scoped rules target by default.
#   * BAD_K / BAD_OPC         - the prepared "bad" vector used to force an
#     authentication reject (AMF_Auth_Reject).
# ---------------------------------------------------------------------------
DEFAULT_SUBSCRIBER_IMSI="${OPEN5GS_SUBSCRIBER_IMSI:-208990100001100}"
DEFAULT_ALARM_NF="${OPEN5GS_ALARM_NF:-amf}"
BAD_K="00000000000000000000000000000000"
BAD_OPC="00000000000000000000000000000000"

log() { printf '%s\n' "[$(date '+%Y-%m-%dT%H:%M:%S')] $*" | tee -a "${LOG_FILE}" >&2; }
die() { log "ERROR: $*"; exit 1; }

require_core() {
  docker ps --format '{{.Names}}' | grep -qx "${core_container}" \
    || die "core container not running: ${core_container}"
}

# restart_core: restart Open5GS and the co-tenanted EMS. EMSS-O5GC joins the
# core container's network namespace (network_mode: service:...), so a core
# restart recreates the netns and orphans the EMS - it must be restarted too or
# metric scraping / AAL polling dies. Also resets the in-memory NF session table
# (SMF -> ues_active=0) and the cumulative counter session.
restart_core() {
  require_core
  docker restart "${core_container}" >/dev/null
  docker restart "${ems_container}" >/dev/null
  log "restarted ${core_container} + ${ems_container} (fresh NF session epoch)"
}

# ---------------------------------------------------------------------------
# Real fault primitives
# ---------------------------------------------------------------------------
nf_daemon() {
  case "$1" in
    nrf) echo open5gs-nrfd ;; udr) echo open5gs-udrd ;; udm) echo open5gs-udmd ;;
    ausf) echo open5gs-ausfd ;; pcf) echo open5gs-pcfd ;; nssf) echo open5gs-nssfd ;;
    bsf) echo open5gs-bsfd ;; upf) echo open5gs-upfd ;; smf) echo open5gs-smfd ;;
    amf) echo open5gs-amfd ;; *) echo "" ;;
  esac
}

# nf_sig <nf> <STOP|CONT> - freeze/unfreeze a NF process (container stays up).
nf_sig() {
  local nf="$1" sig="$2" daemon pids
  daemon="$(nf_daemon "${nf}")"
  [ -n "${daemon}" ] || die "unknown NF: ${nf}"
  require_core
  pids="$(docker exec "${core_container}" sh -c "pgrep -x '${daemon}' || true")"
  [ -n "${pids}" ] || die "no running ${daemon} process (is the NF up?)"
  for pid in ${pids}; do
    docker exec "${core_container}" sh -c "kill -${sig} ${pid}"
    log "SIG${sig} -> ${daemon} (pid ${pid})"
  done
}

# gnb_set <stop|start> - the NGAP association is broken.
gnb_set() {
  require_core
  docker "${1}" "${gnb_container}" >/dev/null
  log "gNB ${1} (${gnb_container})"
}

# ue_set <stop|start> - drop / re-attach the NR-UE. Its process exits when the
# gNB socket dies ("Lost socket"), so on restore we (re)start it to re-attach.
ue_set() {
  case "$1" in
    stop)  docker stop "${ue_container}" >/dev/null ;;
    start) docker "${2:-restart}" "${ue_container}" >/dev/null ;;
    *) die "ue_set: want stop|start, got $1" ;;
  esac
  log "NR-UE ${1} (${ue_container})"
}

# iptables_rule <add|del> <proto> <dport> [comment] - real network-level fault
# in the shared 5GC netns (Sx/PFCP 8805, N3/GTP-U 2152 are all on loopback).
iptables_rule() {
  local action="$1" proto="$2" dport="$3" tag="$4"
  require_core
  local cmd=(-A)
  [ "${action}" = del ] && cmd=(-D)
  docker exec "${core_container}" sh -c \
    "iptables -m comment --comment 'o5gs-$tag' ${cmd[0]} OUTPUT -o lo -p ${proto} --dport ${dport} -j DROP"
  log "${action} iptables: ${proto} :${dport} (${tag})"
}

iptables_undrop_all() {
  require_core
  docker exec "${core_container}" sh -c \
    "iptables-save | grep -E 'o5gs-(pfcp|n3)' | sed -e 's/-A/-D/' | iptables-restore || true" || true
  log "removed all o5gs pfcp/n3 iptables drops"
}

# In the loopback netns every rule is added/removed twice (OUTPUT + INPUT).
pfcp_drop() { iptables_rule add udp 8805 pfcp; iptables_rule add udp 8805 pfcp-in; }
pfcp_undrop() { iptables_rule del udp 8805 pfcp; iptables_rule del udp 8805 pfcp-in; }
n3_drop() { iptables_rule add udp 2152 n3; iptables_rule add udp 2152 n3-in; }
n3_undrop() { iptables_rule del udp 2152 n3; iptables_rule del udp 2152 n3-in; }

# Subscriber-DB edits (real config faults). Documents are read/written via the
# Open5GS MongoDB. <imsi> is passed as $1 or $SUBSCRIBER_IMSI.
mongo_eval() {
  docker exec "${mongo_container}" mongosh "${mongo_db}" --quiet --eval "$1" 2>/dev/null || true
}

mongo_sub_dump() {
  local imsi="$1"
  mongo_eval "print(EJSON.stringify(db.subscribers.find({imsi:'${imsi}'}).toArray()))"
}

# mongo_sub_del <imsi> - remove the subscription: next Initial/Mobility/Periodic/
# Emergency registration is rejected (unknown subscriber) -> real reg fail.
mongo_sub_del() {
  local imsi="${1:-${SUBSCRIBER_IMSI:-$DEFAULT_SUBSCRIBER_IMSI}}"
  require_core
  mongo_eval "print('removed='+db.subscribers.deleteOne({imsi:'${imsi}'}).deletedCount)"
  log "subscriber ${imsi} removed from ${mongo_container}/${mongo_db}"
  echo "ACTION REQUIRED: UE must now attempt the registration procedure to move"
  echo "      rm_reg* / amf_auth* counters (re-attach the UE / nr-ue)."
}

# mongo_sub_restore <imsi> <raw-json-from-sub_dump> - put the subscription back.
mongo_sub_restore() {
  local imsi="$1" doc="$2"
  [ -n "${doc}" ] && [ "${doc}" != "[]" ] || die "empty subscriber dump for ${imsi}"
  mongo_eval "db.subscribers.insertMany(${doc})"
  log "subscriber ${imsi} restored"
}

# mongo_wrong_k <imsi> - corrupt the security vector (prepared BAD_K/BAD_OPC);
# the UE's next authentication attempt is rejected by the network.
mongo_wrong_k() {
  local imsi="${1:-${SUBSCRIBER_IMSI:-$DEFAULT_SUBSCRIBER_IMSI}}"
  mongo_eval "db.subscribers.updateOne({imsi:'${imsi}'},\$set:{security:{k:'${BAD_K}',opc:'${BAD_OPC}'}})"
  log "subscriber ${imsi} K/opc corrupted -> auth will reject"
  echo "ACTION REQUIRED: UE re-authentication to observe amf_authreject increments."
}

# mongo_snapshot_to <file> <imsi> - persist the subscriber doc for restore.
mongo_snapshot_to() {
  local file="$1" imsi="$2"
  mongo_eval "print(EJSON.stringify(db.subscribers.find({imsi:'${imsi}'}).toArray()))" > "${file}"
  log "snapshotted subscriber ${imsi} -> ${file}"
}

# mongo_restore_from <file> <imsi> - restore a previously snapshotted doc:
# drops the (possibly corrupted) doc then re-inserts the original byte-for-byte.
mongo_restore_from() {
  local file="$1" imsi="$2" doc
  [ -f "${file}" ] || die "no snapshot ${file} for ${imsi} - run the matching o5gs-alarm-<name> first"
  doc="$(tr -d '\n' < "${file}" | sed 's/^ *//')"
  [ -n "${doc}" ] && [ "${doc}" != "[]" ] || die "snapshot ${file} is empty - nothing to restore for ${imsi}"
  base="${doc//\'/\\\'}"
  mongo_eval "db.subscribers.deleteOne({imsi:'${imsi}'}); db.subscribers.insertMany(EJSON.parse('${base}'))"
  log "restored subscriber ${imsi} from ${file}"
}

# ---------------------------------------------------------------------------
# AAL poll + wait helpers (verify the alarm actually appears / clears)
# ---------------------------------------------------------------------------
_poll_aal() {
  local nf="$1" code="$2" out
  out="$(POLL_INTERVAL=0 NETCONF_EMS_CONTAINER=EMS-O5GC "${poll_script}" 127.0.0.1 8304 "${nf}-alarms" 0 0 2>/dev/null || true)"
  grep -q "${code}" <<<"${out}" && echo 1 || echo 0
}

wait_for_alarm() {
  local nf="$1" code="$2" t="${3:-90}" i=0
  while [ "${i}" -lt "${t}" ]; do
    if [ "$(_poll_aal "${nf}" "${code}")" = "1" ]; then
      log "CONFIRMED ACTIVE: ${code} on ${nf} (after ~${i}s)"
      return 0
    fi
    sleep 5; i=$((i+5))
  done
  die "timed out waiting for ACTIVE ${code} on ${nf}"
}

wait_for_clear() {
  local nf="$1" code="$2" t="${3:-90}" i=0
  while [ "${i}" -lt "${t}" ]; do
    if [ "$(_poll_aal "${nf}" "${code}")" = "0" ]; then
      log "CONFIRMED CLEARED: ${code} on ${nf} (after ~${i}s)"
      return 0
    fi
    sleep 5; i=$((i+5))
  done
  die "timed out waiting for clear of ${code} on ${nf}"
}

# ---------------------------------------------------------------------------
# Public dispatcher used by every <alarm>/raise.sh and <alarm>/restore.sh.
#
# alarm_raise   <name> [imsi]   - induce the fault, wait for ACTIVE.
# alarm_restore <name> [imsi]   - undo the fault, wait for CLEARED.
# ---------------------------------------------------------------------------
alarm_raise() {
  local name="$1" imsi="${2:-${SUBSCRIBER_IMSI:-}}" nf extra
  case "${name}" in
    nf_unreachable)
      nf="${ALARM_NF:-amf}"; nf_sig "${nf}" STOP
      wait_for_alarm "${nf}" "Alarm_O5GS_NF_Unreachable" "${ALARM_WAIT:-60}" ;;
    ngap_sctp_assoc_down)
      gnb_set stop; wait_for_alarm "amf" "Alarm_O5GS_NGAP_SCTP_Assoc_Down" "${ALARM_WAIT:-120}" ;;
    amf_gnb_count_dropped)
      gnb_set stop; wait_for_alarm "amf" "Alarm_O5GS_AMF_Gnb_Count_Dropped" "${ALARM_WAIT:-120}" ;;
    smf_pfcp_peer_loss)
      pfcp_drop; wait_for_alarm "smf" "Alarm_O5GS_SMF_Pfcp_Peer_Loss" "${ALARM_WAIT:-120}" ;;
    smf_n4_sess_estab_fail)
      pfcp_drop; wait_for_alarm "smf" "Alarm_O5GS_SMF_N4_Sess_Estab_Fail" "${ALARM_WAIT:-120}" ;;
    smf_n4_report_fail)
      pfcp_drop; wait_for_alarm "smf" "Alarm_O5GS_SMF_N4_Report_Fail" "${ALARM_WAIT:-120}" ;;
    upf_n4_sess_estab_fail)
      pfcp_drop; wait_for_alarm "upf" "Alarm_O5GS_UPF_N4_Sess_Estab_Fail" "${ALARM_WAIT:-120}" ;;
    upf_n3_data_stagnation)
      n3_drop; wait_for_alarm "upf" "Alarm_O5GS_UPF_N3_Data_Stagnation" "${ALARM_WAIT:-120}" ;;
    amf_reg_init_fail)
      mongo_sub_del "${imsi}"; wait_for_alarm "amf" "Alarm_O5GS_AMF_Reg_Init_Fail" "${ALARM_WAIT:-180}" ;;
    amf_reg_mob_fail)
      mongo_sub_del "${imsi}"; wait_for_alarm "amf" "Alarm_O5GS_AMF_Reg_Mob_Fail" "${ALARM_WAIT:-180}" ;;
    amf_reg_period_fail)
      mongo_sub_del "${imsi}"; wait_for_alarm "amf" "Alarm_O5GS_AMF_Reg_Period_Fail" "${ALARM_WAIT:-180}" ;;
    amf_reg_emerg_fail)
      mongo_sub_del "${imsi}"; wait_for_alarm "amf" "Alarm_O5GS_AMF_Reg_Emerg_Fail" "${ALARM_WAIT:-180}" ;;
    pdu_session_failure)
      mongo_sub_del "${imsi}"; wait_for_alarm "smf" "Alarm_O5GS_PDU_Session_Failure" "${ALARM_WAIT:-180}" ;;
    amf_auth_reject_rate)
      mongo_wrong_k "${imsi}"; wait_for_alarm "amf" "Alarm_O5GS_AMF_Auth_Reject" "${ALARM_WAIT:-180}" ;;
    nf_unexpected_restart)
      restart_core
      wait_for_alarm "${ALARM_NF:-amf}" "Alarm_O5GS_NF_Unexpected_Restart" "${ALARM_WAIT:-180}" ;;
    amf_zero_connected_ues)
      gnb_set stop; ue_set stop; wait_for_alarm "amf" "Alarm_O5GS_AMF_Zero_Connected_UEs" "${ALARM_WAIT:-180}" ;;
    smf_zero_active_ues)
      ue_set stop; restart_core; wait_for_alarm "smf" "Alarm_O5GS_SMF_Zero_Active_UEs" "${ALARM_WAIT:-180}" ;;
    *) die "unknown alarm: ${name}" ;;
  esac
  log "RAISE complete: ${name}"
}

alarm_restore() {
  local name="$1" imsi="${2:-${SUBSCRIBER_IMSI:-}}" nf extra
  case "${name}" in
    nf_unreachable)
      nf="${ALARM_NF:-amf}"; require_core; nf_sig "${nf}" CONT
      wait_for_clear "${nf}" "Alarm_O5GS_NF_Unreachable" "${ALARM_WAIT:-60}" ;;
    ngap_sctp_assoc_down)
      require_core; gnb_set start; sleep 5; ue_set start restart
      wait_for_clear "amf" "Alarm_O5GS_NGAP_SCTP_Assoc_Down" "${ALARM_WAIT:-150}" ;;
    amf_gnb_count_dropped)
      require_core; gnb_set start; sleep 5; ue_set start restart
      wait_for_clear "amf" "Alarm_O5GS_AMF_Gnb_Count_Dropped" "${ALARM_WAIT:-150}" ;;
    smf_pfcp_peer_loss)
      pfcp_undrop; wait_for_clear "smf" "Alarm_O5GS_SMF_Pfcp_Peer_Loss" "${ALARM_WAIT:-120}" ;;
    smf_n4_sess_estab_fail)
      pfcp_undrop; wait_for_clear "smf" "Alarm_O5GS_SMF_N4_Sess_Estab_Fail" "${ALARM_WAIT:-120}" ;;
    smf_n4_report_fail)
      pfcp_undrop; wait_for_clear "smf" "Alarm_O5GS_SMF_N4_Report_Fail" "${ALARM_WAIT:-120}" ;;
    upf_n4_sess_estab_fail)
      pfcp_undrop; wait_for_clear "upf" "Alarm_O5GS_UPF_N4_Sess_Estab_Fail" "${ALARM_WAIT:-120}" ;;
    upf_n3_data_stagnation)
      n3_undrop; wait_for_clear "upf" "Alarm_O5GS_UPF_N3_Data_Stagnation" "${ALARM_WAIT:-120}" ;;
    amf_reg_init_fail)
      die "restore needs the snapshotted subscriber re-inserted - see amf_reg_init_fail/restore.sh (mongo_restore_from)." ;;
    amf_reg_mob_fail)
      die "restore needs the snapshotted subscriber re-inserted - see amf_reg_mob_fail/restore.sh." ;;
    amf_reg_period_fail)
      die "restore needs the snapshotted subscriber re-inserted - see amf_reg_period_fail/restore.sh." ;;
    amf_reg_emerg_fail)
      die "restore needs the snapshotted subscriber re-inserted - see amf_reg_emerg_fail/restore.sh." ;;
    pdu_session_failure)
      die "restore needs the snapshotted subscriber re-inserted - see pdu_session_failure/restore.sh." ;;
    amf_auth_reject_rate)
      die "restore needs the correct K/opc restored - see amf_auth_reject_rate/restore.sh." ;;
    amf_zero_connected_ues)
      require_core; gnb_set start; sleep 5; ue_set start restart
      wait_for_clear "amf" "Alarm_O5GS_AMF_Zero_Connected_UEs" "${ALARM_WAIT:-180}" ;;
    smf_zero_active_ues)
      require_core; gnb_set start; sleep 5; ue_set start restart
      wait_for_clear "smf" "Alarm_O5GS_SMF_Zero_Active_UEs" "${ALARM_WAIT:-180}" ;;
    nf_unexpected_restart)
      restart_core
      wait_for_clear "${ALARM_NF:-amf}" "Alarm_O5GS_NF_Unexpected_Restart" "${ALARM_WAIT:-180}" ;;
    *) die "restore-${name}: no real undo defined in lib.sh" ;;
  esac
  log "RESTORE complete: ${name}"
}

# resolve_imsi: pick the subscriber IMSI from (in order) $1, $SUBSCRIBER_IMSI or the default.
resolve_imsi() {
  local imsi="${1:-${SUBSCRIBER_IMSI:-$DEFAULT_SUBSCRIBER_IMSI}}"
  log "subscriber IMSI=${imsi} (override via SUBSCRIBER_IMSI=<imsi> or pass as argv)"
  printf '%s' "${imsi}"
}