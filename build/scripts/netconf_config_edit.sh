#!/usr/bin/env bash
set -euo pipefail

host=${1:-127.0.0.1}
port=${2:-8301}
key=${3:-n_prb}
value=${4:-}
action=${5:-commit}
commit_timeout_ms=${NETCONF_COMMIT_TIMEOUT_MS:-120000}
validate_after_edit=${NETCONF_VALIDATE_AFTER_EDIT:-1}

if [[ -z "${value}" ]]; then
  echo "usage: $0 <host> <port> <key> <value> [commit|no-commit|discard]" >&2
  exit 2
fi

client=${NETCONF_CLIENT:-}
ems_container=${NETCONF_EMS_CONTAINER:-}
if [[ -n "${ems_container}" ]]; then
  priv_key=${NETCONF_PRIV_KEY:-/app/netconf/client_key}
  pub_key=${NETCONF_PUB_KEY:-/app/netconf/client_key.pub}
  known_hosts=${NETCONF_KNOWN_HOSTS:-/app/netconf/known_hosts}
else
  priv_key=${NETCONF_PRIV_KEY:-externals/lte-element-manager/netconf/keys/client_key}
  pub_key=${NETCONF_PUB_KEY:-externals/lte-element-manager/netconf/keys/authorized_keys}
  known_hosts=${NETCONF_KNOWN_HOSTS:-netconf/known_hosts}
fi
known_hosts_mode=${NETCONF_KNOWN_HOSTS_MODE:-accept}

nrmsn=${NETCONF_NRM_SUBNETWORK:-srsRAN}
nrmme=${NETCONF_NRM_MANAGED_ELEMENT:-enb1}
nrmfn=${NETCONF_NRM_ENB_FUNCTION_ID:-1}
nrmcell=${NETCONF_NRM_EUTRAN_CELL_ID:-1}

if [[ -z "${ems_container}" ]]; then
  if [[ ! -f "${priv_key}" || ! -f "${pub_key}" ]]; then
    build/scripts/netconf_keys.sh >/dev/null
  fi
fi

run_client() {
  if [[ -n "${ems_container}" ]]; then
    docker exec -i \
      -e NETCONF_KNOWN_HOSTS="${known_hosts}" \
      -e NETCONF_KNOWN_HOSTS_MODE="${known_hosts_mode}" \
      "${ems_container}" /app/netconf-client "$@"
  else
    "${client}" "$@"
  fi
}

if [[ -n "${ems_container}" ]]; then
  if ! docker ps --format '{{.Names}}' | grep -qx "${ems_container}"; then
    echo "ems container not running: ${ems_container}" >&2
    exit 1
  fi
  docker exec -i "${ems_container}" sh -c "touch \"${known_hosts}\"" >/dev/null 2>&1 || true
else
  if [[ -z "${client}" ]]; then
    client="externals/lte-element-manager/.local/bin/netconf-client"
  fi
  if [[ ! -x "${client}" ]]; then
    make -C externals/lte-element-manager netconf-client >/dev/null
  fi
  if [[ ! -x "${client}" ]]; then
    echo "netconf client not found after build attempt: ${client}" >&2
    exit 1
  fi
fi

if [[ -z "${ems_container}" ]]; then
  chmod 600 "${priv_key}" 2>/dev/null || true
  mkdir -p "$(dirname "${known_hosts}")"
  touch "${known_hosts}"
  export NETCONF_KNOWN_HOSTS="${known_hosts}"
  export NETCONF_KNOWN_HOSTS_MODE="${known_hosts_mode}"
fi

tmp="$(mktemp -t netconf-edit.XXXXXX.xml)"

run_client_stdin() {
  if [[ -n "${ems_container}" ]]; then
    docker exec -i \
      -e NETCONF_KNOWN_HOSTS="${known_hosts}" \
      -e NETCONF_KNOWN_HOSTS_MODE="${known_hosts_mode}" \
      "${ems_container}" /app/netconf-client "$@"
  else
    "${client}" "$@"
  fi
}

cleanup() {
  rm -f "${tmp}"
}
trap cleanup EXIT

leaf_xml=""
case "${key}" in
  enb_id|mcc|mnc|mme_addr|gtp_bind_addr|s1c_bind_addr|s1c_bind_port|n_prb|tm)
    leaf_xml="<cme:${key}>${value}</cme:${key}>"
    ;;
  dl_earfcn|pci)
    leaf_xml="<cme:EUtranCell><cme:id>${nrmcell}</cme:id><cme:${key}>${value}</cme:${key}></cme:EUtranCell>"
    ;;
  cell_id|tac|ho_active|a3_offset|time_to_trigger|hysteresis)
    leaf_xml="<cme:EUtranCell><cme:id>${nrmcell}</cme:id><cme:${key}>${value}</cme:${key}></cme:EUtranCell>"
    ;;
  enb_serial|tx_gain)
    leaf_xml="<srs:${key}>${value}</srs:${key}>"
    ;;
  rx_gain|time_adv_nsamples|device_name|device_args)
    leaf_xml="<srs:${key}>${value}</srs:${key}>"
    ;;
  sched_policy|pdsch_max_mcs|pusch_max_mcs|target_bler|min_nof_ctrl_symbols|max_nof_ctrl_symbols)
    leaf_xml="<srs:scheduler><srs:${key}>${value}</srs:${key}></srs:scheduler>"
    ;;
  q_rx_lev_min|cell_barred|num_ra_preambles|preamble_init_rx_target_pwr|pwr_ramping_step|reference_signal_power|p0_nominal_pusch|p0_nominal_pucch|alpha|default_paging_cycle)
    leaf_xml="<srs:sib><srs:${key}>${value}</srs:${key}></srs:sib>"
    ;;
  t300|t301|t310|n310|t311)
    leaf_xml="<srs:sib><srs:ue_timers_and_constants><srs:${key}>${value}</srs:${key}></srs:ue_timers_and_constants></srs:sib>"
    ;;
  qci_profiles\[*)
    # key format: qci_profiles[7].discard_timer
    if [[ "${key}" =~ ^qci_profiles\[([0-9]+)\]\.([A-Za-z0-9_]+)$ ]]; then
      qci="${BASH_REMATCH[1]}"
      field="${BASH_REMATCH[2]}"
      leaf_xml="<srs:qci_profiles><srs:qci>${qci}</srs:qci><srs:${field}>${value}</srs:${field}></srs:qci_profiles>"
    else
      echo "[netconf] unsupported key format: ${key}" >&2
      exit 2
    fi
    ;;
  pusch_max_its|nr_pusch_max_its|pusch_8bit_decoder|nof_phy_threads|metrics_period_secs|tx_amplitude|rrc_inactivity_timer|rlf_release_timer_ms|eea_pref_list|eia_pref_list|gtpu_tunnel_timeout|s1_setup_max_retries|s1_connect_timer|rx_gain_offset|use_cedron_f_est_alg|rlf_min_ul_snr_estim|max_mac_dl_kos|max_mac_ul_kos)
    leaf_xml="<srs:expert><srs:${key}>${value}</srs:${key}></srs:expert>"
    ;;
  *)
    echo "[netconf] unsupported key: ${key}" >&2
    exit 2
    ;;
esac

cat >"${tmp}" <<EOF
<cme:SubNetwork xmlns:cme="urn:3gpp:sa5:_3gpp-common-managed-element" xmlns:srs="urn:vendor:srsran:ext">
  <cme:id>${nrmsn}</cme:id>
  <cme:ManagedElement>
    <cme:id>${nrmme}</cme:id>
    <cme:ENBFunction>
      <cme:id>${nrmfn}</cme:id>
      ${leaf_xml}
    </cme:ENBFunction>
  </cme:ManagedElement>
</cme:SubNetwork>
EOF

echo "[netconf] get-config running:"
run_client -H "${host}" -p "${port}" -P "${pub_key}" -i "${priv_key}" get-config running || true
echo ""

echo "[netconf] get-config candidate:"
run_client -H "${host}" -p "${port}" -P "${pub_key}" -i "${priv_key}" get-config candidate || true
echo ""

sequence_action="${action}"
if [[ "${validate_after_edit}" != "1" ]]; then
  echo "[netconf] warning: sequence mode always validates candidate before commit/discard" >&2
fi

echo "[netconf] sequence ${key}=${value} action=${sequence_action}"
if [[ -n "${ems_container}" ]]; then
  docker exec -i \
    -e NETCONF_KNOWN_HOSTS="${known_hosts}" \
    -e NETCONF_KNOWN_HOSTS_MODE="${known_hosts_mode}" \
    -e NETCONF_RPC_TIMEOUT_MS="${commit_timeout_ms}" \
    "${ems_container}" /app/netconf-client \
    -H "${host}" -p "${port}" -P "${pub_key}" -i "${priv_key}" sequence - "${sequence_action}" < "${tmp}"
else
  NETCONF_RPC_TIMEOUT_MS="${commit_timeout_ms}" run_client_stdin \
    -H "${host}" -p "${port}" -P "${pub_key}" -i "${priv_key}" sequence - "${sequence_action}" < "${tmp}"
fi

if [[ "${action}" == "commit" ]]; then
  echo ""
  echo "[netconf] get-config running after commit:"
  run_client -H "${host}" -p "${port}" -P "${pub_key}" -i "${priv_key}" get-config running || true
elif [[ "${action}" == "discard" ]]; then
  echo "[netconf] get-config candidate after discard:"
  run_client -H "${host}" -p "${port}" -P "${pub_key}" -i "${priv_key}" get-config candidate || true
else
  echo "[netconf] commit skipped (action=${action})"
fi
