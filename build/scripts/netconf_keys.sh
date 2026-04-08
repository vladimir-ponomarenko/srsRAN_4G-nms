#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
key_dir=${NETCONF_KEY_DIR:-"$repo_root/externals/lte-element-manager/netconf/keys"}
export_dir=${NETCONF_EXPORT_DIR:-"$repo_root/netconf/keys"}

mkdir -p "$key_dir"
mkdir -p "$export_dir"

hostkey="$key_dir/hostkey"
client_key="$key_dir/client_key"
client_pub="$key_dir/client_key.pub"
authorized_keys="$key_dir/authorized_keys"

ensure_pem() {
  local key_path=$1
  if [ ! -f "$key_path" ]; then
    ssh-keygen -t rsa -b 2048 -m PEM -N "" -f "$key_path" >/dev/null
    return
  fi
  if head -n 1 "$key_path" | grep -q "OPENSSH"; then
    ssh-keygen -p -m PEM -N "" -f "$key_path" >/dev/null
  fi
}

ensure_pem "$hostkey"
ensure_pem "$client_key"

if [ -f "$client_pub" ]; then
  cp "$client_pub" "$authorized_keys"
fi

chmod 600 "$hostkey" "$client_key" 2>/dev/null || true
chmod 644 "$authorized_keys" "$client_pub" 2>/dev/null || true

cp -f "$authorized_keys" "$export_dir/authorized_keys"
cp -f "$client_pub" "$export_dir/client_key.pub"
cp -f "$hostkey.pub" "$export_dir/hostkey.pub"
cp -f "$client_key" "$export_dir/client_key"
cp -f "$hostkey" "$export_dir/hostkey"
chmod 600 "$export_dir/client_key" "$export_dir/hostkey" 2>/dev/null || true
chmod 644 "$export_dir/authorized_keys" "$export_dir/client_key.pub" "$export_dir/hostkey.pub" 2>/dev/null || true

echo "netconf keys ready: $key_dir"
echo "netconf keys exported: $export_dir"
