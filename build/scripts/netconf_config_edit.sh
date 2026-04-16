#!/usr/bin/env bash
set -euo pipefail

host=${1:-127.0.0.1}
port=${2:-8301}
key=${3:-n_prb}
value=${4:-}
do_commit=${5:-commit}
commit_timeout_ms=${NETCONF_COMMIT_TIMEOUT_MS:-120000}

if [[ -z "${value}" ]]; then
  echo "usage: $0 <host> <port> <key> <value> [commit|no-commit]" >&2
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
cleanup() { rm -f "${tmp}"; }
trap cleanup EXIT

leaf_xml=""
case "${key}" in
  mcc|mnc|n_prb)
    leaf_xml="<cme:${key}>${value}</cme:${key}>"
    ;;
  dl_earfcn|pci)
    leaf_xml="<cme:EUtranCell><cme:id>${nrmcell}</cme:id><cme:${key}>${value}</cme:${key}></cme:EUtranCell>"
    ;;
  enb_serial|tx_gain)
    leaf_xml="<srs:${key}>${value}</srs:${key}>"
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

echo "[netconf] edit-config candidate ${key}=${value}"
if [[ -n "${ems_container}" ]]; then
  docker exec -i \
    -e NETCONF_KNOWN_HOSTS="${known_hosts}" \
    -e NETCONF_KNOWN_HOSTS_MODE="${known_hosts_mode}" \
    "${ems_container}" /app/netconf-client \
    -H "${host}" -p "${port}" -P "${pub_key}" -i "${priv_key}" edit-config candidate - < "${tmp}"
else
  run_client -H "${host}" -p "${port}" -P "${pub_key}" -i "${priv_key}" edit-config candidate "${tmp}"
fi
echo ""

echo "[netconf] get-config candidate after edit:"
run_client -H "${host}" -p "${port}" -P "${pub_key}" -i "${priv_key}" get-config candidate || true
echo ""

if [[ "${do_commit}" == "commit" ]]; then
  echo "[netconf] commit"
  if [[ -n "${ems_container}" ]]; then
    docker exec -i \
      -e NETCONF_KNOWN_HOSTS="${known_hosts}" \
      -e NETCONF_KNOWN_HOSTS_MODE="${known_hosts_mode}" \
      -e NETCONF_RPC_TIMEOUT_MS="${commit_timeout_ms}" \
      "${ems_container}" /app/netconf-client \
      -H "${host}" -p "${port}" -P "${pub_key}" -i "${priv_key}" commit
  else
    NETCONF_RPC_TIMEOUT_MS="${commit_timeout_ms}" run_client -H "${host}" -p "${port}" -P "${pub_key}" -i "${priv_key}" commit
  fi
  echo ""
  echo "[netconf] get-config running after commit:"
  run_client -H "${host}" -p "${port}" -P "${pub_key}" -i "${priv_key}" get-config running || true
else
  echo "[netconf] commit skipped (5th arg is not 'commit')"
fi
