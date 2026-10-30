#!/usr/bin/env bash
# synthetic.sh - SYNTHETIC Open5GS alarm demo tool.
#
# Forces a metric view into the Open5GS TCA engine through the EMS /inject
# endpoint so ANY alarm can be demonstrated deterministically, even ones that a
# minimal 1-UE lab cannot break with a real fault (see docs/5g/synthetic-alarms.md).
#
# This is a DEBUG/DEMO tool: it OVERRIDES the scraped metric with a forced value
# and, on clear/reset, lets the real Open5GS telemetry drive the engine again.
# It never touches real services; it is the counterpart to the REAL, fault-driven
# per-alarm scripts (./<alarm>/raise.sh, made with `make o5gs-alarm-*`).
#
# Uses the EMS-O5GC HTTP injection endpoint (published on host :18084; it must
# be enabled: test_injection_enabled: true in config/ems-agent-open5gs.yaml).
#
# Usage:
#   synthetic.sh raise <alarm> [nf]     - force the values that cross the threshold
#   synthetic.sh clear <alarm> [nf]     - reset that NF override -> real telemetry
#   synthetic.sh set  <nf> <metric> <v> - low-level: force one metric value
#   synthetic.sh reset <nf>             - low-level: drop all overrides for an NF
#   synthetic.sh list                   - show every alarm -> (nf, metrics) mapping
#   synthetic.sh all                    - raise EVERY synthetic-capable alarm (debug/test)
#   synthetic.sh clear-all              - reset every NF override -> real telemetry
#
# SPDX-License-Identifier: LicenseRef-CSSL-1.0
set -euo pipefail

host=${INJECT_HOST:-127.0.0.1}
port=${INJECT_PORT:-18084}
base="http://${host}:${port}"

# alarm -> (nf, alarm-code, space-separated metric=value that CROSSES the rule).
# Values follow the thresholds in internal/ems/fcaps/o5gstca/config.go.
declare -A NF=() CODE=() METRICS=()
register() { # register <alarm> <nf> <code> <metric=value ...>
  NF["$1"]=$2; CODE["$1"]=$3; METRICS["$1"]=$4
}
register amf_reg_init_fail      amf Alarm_O5GS_AMF_Reg_Init_Fail      "fivegs_amffunction_rm_reginitsucc=0 fivegs_amffunction_rm_reginitreq=10"
register amf_reg_mob_fail       amf Alarm_O5GS_AMF_Reg_Mob_Fail       "fivegs_amffunction_rm_regmobsucc=0 fivegs_amffunction_rm_regmobreq=10"
register amf_reg_period_fail    amf Alarm_O5GS_AMF_Reg_Period_Fail    "fivegs_amffunction_rm_regperiodsucc=0 fivegs_amffunction_rm_regperiodreq=10"
register amf_reg_emerg_fail     amf Alarm_O5GS_AMF_Reg_Emerg_Fail     "fivegs_amffunction_rm_regemergsucc=0 fivegs_amffunction_rm_regemergreq=10"
register amf_auth_reject_rate   amf Alarm_O5GS_AMF_Auth_Reject        "fivegs_amffunction_amf_authreq=10 fivegs_amffunction_amf_authreject=10"
register amf_paging_fail_rate   amf Alarm_O5GS_AMF_Paging_Fail        "fivegs_amffunction_mm_paging5gsucc=0 fivegs_amffunction_mm_paging5greq=10"
register amf_conf_update_fail   amf Alarm_O5GS_AMF_Conf_Update_Fail   "fivegs_amffunction_mm_confupdatesucc=0 fivegs_amffunction_mm_confupdate=10"
register amf_ran_ue_capacity    amf Alarm_O5GS_AMF_RanUe_Capacity     "ran_ue=900"
register amf_gnb_count_dropped  amf Alarm_O5GS_AMF_Gnb_Count_Dropped  "gnb=0"
register amf_zero_connected_ues amf Alarm_O5GS_AMF_Zero_Connected_UEs "ran_ue=0"
register ngap_sctp_assoc_down   amf Alarm_O5GS_NGAP_SCTP_Assoc_Down   "gnb=0"
register smf_pfcp_peer_loss     smf Alarm_O5GS_SMF_Pfcp_Peer_Loss     "pfcp_peers_active=0"
register smf_n4_sess_estab_fail smf Alarm_O5GS_SMF_N4_Sess_Estab_Fail "fivegs_smffunction_sm_n4sessionreportsucc=0 fivegs_smffunction_sm_n4sessionreport=10"
register smf_n4_report_fail     smf Alarm_O5GS_SMF_N4_Report_Fail     "fivegs_smffunction_sm_n4sessionreportsucc=0 fivegs_smffunction_sm_n4sessionreport=10"
register smf_active_bearer_limit smf Alarm_O5GS_SMF_Bearer_Limit      "bearers_active=900"
register smf_zero_active_ues    smf Alarm_O5GS_SMF_Zero_Active_UEs    "ues_active=0"
register smf_gtpv1c_parse_error smf Alarm_O5GS_SMF_GTPv1C_Parse_Error "gn_rx_parse_failed=1"
register smf_gtpv2c_parse_error smf Alarm_O5GS_SMF_GTPv2C_Parse_Error "s5c_rx_parse_failed=1"
register smf_gtp_new_node_failed smf Alarm_O5GS_SMF_GTP_New_Node_Failed "gtp_new_node_failed=1"
register pdu_session_failure    smf Alarm_O5GS_PDU_Session_Failure    "fivegs_smffunction_sm_pdusessioncreationsucc=0 fivegs_smffunction_sm_pdusessioncreationreq=10"
register upf_n4_sess_estab_fail upf Alarm_O5GS_UPF_N4_Sess_Estab_Fail "fivegs_upffunction_sm_n4sessionreportsucc=0 fivegs_upffunction_sm_n4sessionreport=10"
register upf_session_capacity   upf Alarm_O5GS_UPF_Session_Capacity   "fivegs_upffunction_sm_upf_sessionnbr=900"
register policy_association_failure pcf Alarm_O5GS_Policy_Association_Failure "fivegs_pcffunction_pa_policyamassosucc=0 fivegs_pcffunction_pa_policyamassoreq=10"
# Platform rules run for amf/smf/upf/pcf; nf is passed as the 2nd arg (default amf).
register nf_unreachable         amf Alarm_O5GS_NF_Unreachable      "__reachable=0"
register nf_fd_exhaustion_warn  amf Alarm_O5GS_NF_FD_Exhaustion_Warn "process_open_fds=900 process_max_fds=1000"
register nf_fd_exhaustion_crit  amf Alarm_O5GS_NF_FD_Exhaustion_Crit "process_open_fds=960 process_max_fds=1000"
register nf_memory_leak_detect  amf Alarm_O5GS_NF_Memory_Leak       "process_resident_memory_bytes=900000000"

DELTA_ALARMS="nf_cpu_saturation nf_unexpected_restart upf_n3_data_stagnation"


list() {
  echo "alarm -> nf  (forced metrics; 'clear' resets the NF override)"
  echo "-------------------------------------------------------------------"
  for a in "${!METRICS[@]}"; do
    printf '%-24s %-4s %s\n' "${a}" "${NF[$a]}" "${METRICS[$a]}"
  done
  echo "delta-only (use real fault targets, NOT synthetic):"
  echo "  ${DELTA_ALARMS}"
}

post() {
  local url="$1" payload="$2"
  curl -fsS "${base}${url}" -H 'Content-Type: application/json' -d "${payload}" >/dev/null
}

set_metric() { # set <nf> <metric> <value>
  post /inject "{\"nf\":\"$1\",\"metrics\":{\"$2\":$3}}"
  echo "forced ${2}=${3} on ${1}"
}

reset_nf() {
  post /inject/reset "{\"nf\":\"$1\"}"
  echo "reset overrides for ${1} (real telemetry resumes)"
}

raise() {
  local a="$1" nf="${2:-${NF[$1]:-}}"
  if [[ " ${DELTA_ALARMS} " == *" ${a} "* ]]; then
    echo "NOTE: ${a} needs a cross-sample delta; use the REAL fault target:" >&2
    case "${a}" in
      nf_cpu_saturation)     echo "      make o5gs-alarm-nf-cpu-saturation NF=<nf>  (real process CPU load)" >&2 ;;
      nf_unexpected_restart) echo "      make o5gs-alarm-nf-unexpected-restart NF=<nf>" >&2 ;;
      upf_n3_data_stagnation) echo "      make o5gs-alarm-upf-n3-data-stagnation" >&2 ;;
    esac
    return 2
  fi
  [ -n "${nf:-}" ] || { echo "unknown alarm: ${a}" >&2; return 2; }
  local metrics="${METRICS[$a]}"
  local json="{\"nf\":\"${nf}\",\"metrics\":{"
  local m v first=1
  for m in ${metrics}; do
    v="${m#*=}"; m="${m%%=*}"
    [ "${first}" = 1 ] || json="${json},"
    json="${json}\"${m}\":${v}"; first=0
  done
  json="${json}}}"
  post /inject "${json}"
  echo "synthetic raise ${a} on ${nf}: ${METRICS[$a]}"
  echo "  -> $([ -n "${CODE[$a]:-}" ] && echo "wait for ${CODE[$a]}" || true)"
}

clear() {
  local a="$1" nf="${2:-${NF[$1]:-}}"
  [ -n "${nf:-}" ] || { echo "unknown alarm: ${a}" >&2; return 2; }
  reset_nf "${nf}"
}

all() {
  local rc=1
  for a in "${!METRICS[@]}"; do
    if [[ " ${DELTA_ALARMS} " == *" ${a} "* ]]; then
      echo "skipping ${a} (delta-only, not synthetic)" >&2
      continue
    fi
    raise "${a}"
    rc=0
  done
  [ "${rc}" = 0 ]
}

clear_all() {
  local nf
  for nf in amf smf upf pcf; do
    reset_nf "${nf}"
  done
  echo "cleared ALL synthetic overrides (real telemetry resumes)"
}

cmd="${1:-list}"
case "${cmd}" in
  raise) shift; [ $# -ge 1 ] || { echo "usage: synthetic.sh raise <alarm> [nf]" >&2; exit 2; }; raise "$@";;
  clear) shift; [ $# -ge 1 ] || { echo "usage: synthetic.sh clear <alarm> [nf]" >&2; exit 2; }; clear "$@";;
  set)   shift; [ $# -eq 3 ] || { echo "usage: synthetic.sh set <nf> <metric> <value>" >&2; exit 2; }; set_metric "$@";;
  reset) shift; [ $# -eq 1 ] || { echo "usage: synthetic.sh reset <nf>" >&2; exit 2; }; reset_nf "$@";;
  all)        all ;;
  clear-all)  clear_all ;;
  list)  list ;;
  *) echo "usage: $0 <raise|clear|set|reset|list|all|clear-all>" >&2; exit 2;;
esac