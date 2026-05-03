#!/usr/bin/env bash
set -euo pipefail

host=${1:-127.0.0.1}
port=${2:-8301}
interval=${3:-1}
rpc=${4:-"get"}
loop_forever=1

client=${NETCONF_CLIENT:-}
ems_container=${NETCONF_EMS_CONTAINER:-}

if [ -n "${ems_container}" ]; then
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

if [ -z "${ems_container}" ]; then
  if [ ! -f "${priv_key}" ] || [ ! -f "${pub_key}" ]; then
    build/scripts/netconf_keys.sh >/dev/null
  fi
fi

run_client() {
  if [ -n "${ems_container}" ]; then
    docker exec -i \
      -e NETCONF_KNOWN_HOSTS="${known_hosts}" \
      -e NETCONF_KNOWN_HOSTS_MODE="${known_hosts_mode}" \
      "${ems_container}" /app/netconf-client "$@"
  else
    "${client}" "$@"
  fi
}

if [ -n "${ems_container}" ]; then
  if ! docker ps --format '{{.Names}}' | grep -qx "${ems_container}"; then
    echo "ems container not running: ${ems_container}" >&2
    exit 1
  fi
  docker exec -i "${ems_container}" sh -c "touch \"${known_hosts}\"" >/dev/null 2>&1 || true
else
  if [ -z "${client}" ]; then
    client="externals/lte-element-manager/.local/bin/netconf-client"
  fi
  if [ ! -x "${client}" ]; then
    make -C externals/lte-element-manager netconf-client >/dev/null
  fi
  if [ ! -x "${client}" ]; then
    echo "netconf client not found after build attempt: ${client}" >&2
    exit 1
  fi
fi

if [ -z "${ems_container}" ]; then
  chmod 600 "${priv_key}" 2>/dev/null || true
  mkdir -p "$(dirname "${known_hosts}")"
  touch "${known_hosts}"
  export NETCONF_KNOWN_HOSTS="${known_hosts}"
  export NETCONF_KNOWN_HOSTS_MODE="${known_hosts_mode}"
fi

case "${rpc}" in
  "<get/>"|"get")
    rpc_cmd="get"
    ;;
  "get-nrm")
    rpc_cmd="get"
    # Use prefixless XPath so the libnetconf2 example client does not need custom YANG modules
    # to validate prefixes locally.
    rpc_xpath="/*[local-name()='SubNetwork'][*[local-name()='id']='${nrmsn}']"\
"/*[local-name()='ManagedElement'][*[local-name()='id']='${nrmme}']"\
"/*[local-name()='ENBFunction'][*[local-name()='id']='${nrmfn}']"
    ;;
  "get-nrm-cells")
    rpc_cmd="get"
    rpc_xpath="/*[local-name()='SubNetwork'][*[local-name()='id']='${nrmsn}']"\
"/*[local-name()='ManagedElement'][*[local-name()='id']='${nrmme}']"\
"/*[local-name()='ENBFunction'][*[local-name()='id']='${nrmfn}']"\
"/*[local-name()='EUtranCell']"
    ;;
  "<get-config/>"|"get-config")
    rpc_cmd="get-config"
    ;;
  "get-config-running")
    rpc_cmd="get-config"
    rpc_ds="running"
    loop_forever=0
    ;;
  "get-config-candidate")
    rpc_cmd="get-config"
    rpc_ds="candidate"
    loop_forever=0
    ;;
  "validate-running")
    rpc_cmd="validate"
    rpc_ds="running"
    loop_forever=0
    ;;
  "validate-candidate")
    rpc_cmd="validate"
    rpc_ds="candidate"
    loop_forever=0
    ;;
  "lock-running")
    rpc_cmd="lock"
    rpc_ds="running"
    loop_forever=0
    ;;
  "lock-candidate")
    rpc_cmd="lock"
    rpc_ds="candidate"
    loop_forever=0
    ;;
  "unlock-running")
    rpc_cmd="unlock"
    rpc_ds="running"
    loop_forever=0
    ;;
  "unlock-candidate")
    rpc_cmd="unlock"
    rpc_ds="candidate"
    loop_forever=0
    ;;
  "commit"|"discard-changes")
    rpc_cmd="${rpc}"
    loop_forever=0
    ;;
  "subscribe-alarms"|"subscribe")
    rpc_cmd="subscribe"
    rpc_duration="${NETCONF_SUBSCRIBE_SECONDS:-30}"
    loop_forever=0
    ;;
  *)
    rpc_cmd="${rpc}"
    ;;
esac

if [ "${host}" != "127.0.0.1" ] && [ "${host}" != "localhost" ]; then
  echo "warning: using remote NETCONF host ${host}:${port}" >&2
fi

while true; do
  if [ -n "${rpc_xpath:-}" ]; then
    if [ -n "${rpc_ds:-}" ]; then
      run_client -H "${host}" -p "${port}" -P "${pub_key}" -i "${priv_key}" "${rpc_cmd}" "${rpc_ds}" "${rpc_xpath}"
    else
      run_client -H "${host}" -p "${port}" -P "${pub_key}" -i "${priv_key}" "${rpc_cmd}" "${rpc_xpath}"
    fi
  else
    if [ -n "${rpc_ds:-}" ]; then
      run_client -H "${host}" -p "${port}" -P "${pub_key}" -i "${priv_key}" "${rpc_cmd}" "${rpc_ds}"
    elif [ -n "${rpc_duration:-}" ]; then
      run_client -H "${host}" -p "${port}" -P "${pub_key}" -i "${priv_key}" "${rpc_cmd}" "${rpc_duration}"
    else
      run_client -H "${host}" -p "${port}" -P "${pub_key}" -i "${priv_key}" "${rpc_cmd}"
    fi
  fi
  if [ "${loop_forever}" -eq 0 ]; then
    break
  fi
  sleep "${interval}"
done
