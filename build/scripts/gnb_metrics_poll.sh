#!/usr/bin/env bash
# Polls the gNB metrics from the EMS agent over NETCONF.
#
# The EMS exposes the OAI gNB telemetry through the ems-gnb-metrics YANG
# module under the 3GPP NR managed-element tree. This is the 5G counterpart
# of the 4G netconf_poll.sh flow: it connects to the EMS-GNB container and
# prints either the full metrics snapshot or a filtered subset.
#
# SPDX-License-Identifier: LicenseRef-CSSL-1.0
set -euo pipefail

host=${1:-127.0.0.1}
port=${2:-8303}
mode=${3:-"metrics"}
loop_forever=${4:-0}
interval=${5:-1}

ems_container=${NETCONF_EMS_CONTAINER:-EMS-GNB}
priv_key=${NETCONF_PRIV_KEY:-/app/netconf/client_key}
pub_key=${NETCONF_PUB_KEY:-/app/netconf/client_key.pub}
known_hosts=${NETCONF_KNOWN_HOSTS:-/app/netconf/known_hosts}
known_hosts_mode=${NETCONF_KNOWN_HOSTS_MODE:-accept}

if ! docker ps --format '{{.Names}}' | grep -qx "${ems_container}"; then
  echo "ems container not running: ${ems_container}" >&2
  exit 1
fi

docker exec "${ems_container}" sh -c "touch \"${known_hosts}\"" >/dev/null 2>&1 || true

# Prefixless XPath keeps the libnetconf2 example client independent of the
# vendor YANG modules: it selects nodes by local name only.
case "${mode}" in
  "metrics")
    # Full telemetry envelope as produced by the gNB metrics xApp.
    rpc_xpath="/*[local-name()='gnb_metrics']"
    ;;
  "e2")
    # E2 agent status: RIC connection, E2AP/KPM dialect, ran functions.
    rpc_xpath="/*[local-name()='gnb_metrics']/*[local-name()='e2_container']"
    ;;
  "ues")
    # Per-UE radio bearers: MAC/RLC/PDCP/GTP statistics.
    rpc_xpath="/*[local-name()='gnb_metrics']/*[local-name()='cell_list']" \
"/*[local-name()='ue_list']"
    ;;
  "kpis")
    # KPM measurements as reported by the gNB (DRB.UEThpDl, RRU.PrbTotDl...).
    rpc_xpath="/*[local-name()='gnb_metrics']/*[local-name()='cell_list']" \
"/*[local-name()='ue_list']/*[local-name()='kpi_list']"
    ;;
  "nrm")
    # 3GPP NR managed object view (GNBCUCPFunction and friends).
    rpc_xpath="/*[local-name()='SubNetwork']/*[local-name()='ManagedElement']"
    ;;
  *)
    echo "unknown mode: ${mode} (metrics|e2|ues|kpis|nrm)" >&2
    exit 2
    ;;
esac

run_client() {
  docker exec -i \
    -e NETCONF_KNOWN_HOSTS="${known_hosts}" \
    -e NETCONF_KNOWN_HOSTS_MODE="${known_hosts_mode}" \
    "${ems_container}" /app/netconf-client \
    -H "${host}" -p "${port}" -P "${pub_key}" -i "${priv_key}" \
    get "${rpc_xpath}"
}

while true; do
  run_client
  if [ "${loop_forever}" = "0" ]; then
    break
  fi
  sleep "${interval}"
done
