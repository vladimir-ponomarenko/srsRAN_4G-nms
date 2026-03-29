#!/usr/bin/env bash
set -euo pipefail

host=${1:-127.0.0.1}
port=${2:-8301}
interval=${3:-1}
rpc=${4:-"get"}

client=${NETCONF_CLIENT:-externals/lte-element-manager/.build/libnetconf2/examples/client}
priv_key=${NETCONF_PRIV_KEY:-externals/lte-element-manager/netconf/keys/client_key}
pub_key=${NETCONF_PUB_KEY:-externals/lte-element-manager/netconf/keys/authorized_keys}

if [ ! -x "${client}" ]; then
  echo "netconf client not found: ${client}" >&2
  exit 1
fi

build_dir="externals/lte-element-manager/.build/libnetconf2"
src_client="externals/lte-element-manager/third_party/libnetconf2/examples/client.c"
src_header="externals/lte-element-manager/third_party/libnetconf2/examples/example.h.in"

need_rebuild=0
if ! "${client}" --help 2>/dev/null | grep -q -- "--loop"; then
  need_rebuild=1
elif [ -f "${client}" ]; then
  if [ -f "${src_client}" ] && [ "$(stat -c %Y "${src_client}")" -gt "$(stat -c %Y "${client}")" ]; then
    need_rebuild=1
  fi
  if [ -f "${src_header}" ] && [ "$(stat -c %Y "${src_header}")" -gt "$(stat -c %Y "${client}")" ]; then
    need_rebuild=1
  fi
fi

if [ "${need_rebuild}" -eq 1 ]; then
  if [ -f "${build_dir}/CMakeCache.txt" ]; then
    cmake --build "${build_dir}" --target client
  else
    echo "libnetconf2 build dir missing: ${build_dir}" >&2
    echo "Run: make -C externals/lte-element-manager libnetconf2" >&2
    exit 1
  fi
fi

chmod 600 "${priv_key}" 2>/dev/null || true

case "${rpc}" in
  "<get/>"|"get")
    rpc_cmd="get"
    ;;
  "<get-config/>"|"get-config")
    rpc_cmd="get-config"
    ;;
  *)
    rpc_cmd="${rpc}"
    ;;
esac

if [ "${host}" != "127.0.0.1" ] && [ "${host}" != "localhost" ]; then
  echo "warning: libnetconf2 example client ignores host, using built-in SSH_ADDRESS" >&2
fi

"${client}" -p "${port}" -P "${pub_key}" -i "${priv_key}" --loop --interval "${interval}" "${rpc_cmd}"
