#!/usr/bin/env bash
#Test prb change
set -euo pipefail

host="${1:-127.0.0.1}"
port="${2:-8301}"
n_prb="${3:-50}"
do_commit="${4:-commit}"

case "${n_prb}" in
  6|15|25|50|75|100) ;;
  *)
    echo "n_prb must be one of: 6 15 25 50 75 100" >&2
    exit 2
    ;;
esac

exec bash build/scripts/netconf_config_edit.sh "${host}" "${port}" n_prb "${n_prb}" "${do_commit}"
