#!/bin/bash
# Entrypoint for the OAI 5G gNB node.
#
# The whole O-RAN management plane of the node lives in this container: the
# nearRT-RIC, the EMS telemetry xApp and the gNB itself.
#
# SPDX-License-Identifier: LicenseRef-CSSL-1.0

set -uo pipefail

METRICS_DIR=/var/run/gnb-metrics
RIC_BIN=/usr/local/bin/nearRT-RIC
XAPP_BIN=/usr/local/bin/ems_gnb_metrics_xapp
OAI_ENTRYPOINT=/opt/oai-gnb/bin/entrypoint.sh

mkdir -p "$METRICS_DIR"

# The nearRT-RIC must accept connections before the gNB E2 agent and the xApp
# start, otherwise both retry in a loop until it is reachable.
if [ -x "$RIC_BIN" ]; then
  echo "== Starting nearRT-RIC"
  "$RIC_BIN" >/var/log/nearRT-RIC.log 2>&1 &
  RIC_PID=$!
else
  echo "WARNING: $RIC_BIN not found, starting the gNB without a RIC" >&2
  RIC_PID=
fi

# The telemetry xApp connects to the loopback RIC and pushes the NR telemetry
# envelope to the EMS agent over a unix datagram socket.
if [ -x "$XAPP_BIN" ]; then
  echo "== Starting EMS metrics xApp"
  "$XAPP_BIN" -a 127.0.0.1 >/var/log/ems-gnb-metrics-xapp.log 2>&1 &
  XAPP_PID=$!
else
  echo "WARNING: $XAPP_BIN not found, starting the gNB without telemetry" >&2
  XAPP_PID=
fi

# Give the RIC a moment to bind before the gNB's E2 agent connects.
sleep 2

cleanup() {
  [ -n "${XAPP_PID:-}" ] && kill "$XAPP_PID" 2>/dev/null
  [ -n "${RIC_PID:-}" ] && kill "$RIC_PID" 2>/dev/null
}
trap cleanup EXIT

echo "== Starting gNB soft modem"
exec "$OAI_ENTRYPOINT" "$@"
