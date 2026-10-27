#!/usr/bin/env bash
# Dumps the Open5GS 5G Core telemetry from the EMS agent over NETCONF.
#
# Acts like an NMS: sends a single NETCONF <get> RPC and prints the raw reply
# exactly as returned by the EMS — no client-side parsing or transformation.
# This mirrors the existing netconf_poll.sh / gnb_metrics_poll.sh behaviour so
# the 5GC path can be eyeballed and compared end-to-end in production.
#
# Usage:
#   bash build/scripts/open5gs_metrics_poll.sh [host] [port] [mode] [loop] [interval]
#
# Modes (default "all"): one-shot raw dump of the served tree.
#   all|nrm        - full SubNetwork (all functions + perf + metrics + info)
#   functions      - the ManagedElement with every *Function list
#   amf|smf|upf|pcf- a single network function subtree
#   <nf>-metrics   - metric list entries of one network function
#   <nf>-performance - aggregated performance leaves of one network function
#   <nf>-info      - structured inventory + raw anydata dump of one function
#   <nf>-dump      - the raw infoAPI responses (anydata dump) of one function
#
# SPDX-License-Identifier: LicenseRef-CSSL-1.0
set -euo pipefail

host=${1:-127.0.0.1}
port=${2:-8304}
mode=${3:-"all"}
loop_forever=${4:-0}
interval=${5:-1}

ems_container=${NETCONF_EMS_CONTAINER:-EMS-O5GC}
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
sn="/*[local-name()='SubNetwork']"
me="${sn}/*[local-name()='ManagedElement']"

case "${mode}" in
  all|nrm)                rpc_xpath="${sn}" ;;
  functions)              rpc_xpath="${me}" ;;
  amf)                    rpc_xpath="${me}/*[local-name()='AmfFunction']" ;;
  smf)                    rpc_xpath="${me}/*[local-name()='SmfFunction']" ;;
  upf)                    rpc_xpath="${me}/*[local-name()='UpfFunction']" ;;
  pcf)                    rpc_xpath="${me}/*[local-name()='PCFFunction']" ;;
  amf-metrics)            rpc_xpath="${me}/*[local-name()='AmfFunction']/*[local-name()='metrics']/*[local-name()='metric']" ;;
  smf-metrics)            rpc_xpath="${me}/*[local-name()='SmfFunction']/*[local-name()='metrics']/*[local-name()='metric']" ;;
  upf-metrics)            rpc_xpath="${me}/*[local-name()='UpfFunction']/*[local-name()='metrics']/*[local-name()='metric']" ;;
  pcf-metrics)            rpc_xpath="${me}/*[local-name()='PCFFunction']/*[local-name()='metrics']/*[local-name()='metric']" ;;
  amf-performance)        rpc_xpath="${me}/*[local-name()='AmfFunction']/*[local-name()='performance']" ;;
  smf-performance)        rpc_xpath="${me}/*[local-name()='SmfFunction']/*[local-name()='performance']" ;;
  upf-performance)        rpc_xpath="${me}/*[local-name()='UpfFunction']/*[local-name()='performance']" ;;
  pcf-performance)        rpc_xpath="${me}/*[local-name()='PCFFunction']/*[local-name()='performance']" ;;
  amf-info)               rpc_xpath="${me}/*[local-name()='AmfFunction']/*[local-name()='info']" ;;
  smf-info)               rpc_xpath="${me}/*[local-name()='SmfFunction']/*[local-name()='info']" ;;
  amf-dump)               rpc_xpath="${me}/*[local-name()='AmfFunction']/*[local-name()='info']/*[local-name()='dump']/*[local-name()='endpoint']" ;;
  smf-dump)               rpc_xpath="${me}/*[local-name()='SmfFunction']/*[local-name()='info']/*[local-name()='dump']/*[local-name()='endpoint']" ;;
  *)
    echo "unknown mode: ${mode}" >&2
    echo "valid: all nrm functions amf smf upf pcf <nf>[-metrics|-performance|-info|-dump]" >&2
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