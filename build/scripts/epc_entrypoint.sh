#!/bin/bash
set -e

sysctl -w net.ipv4.ip_forward=1

iptables -t nat -A POSTROUTING -s 172.16.0.0/24 -o eth0 -j MASQUERADE
echo "--- EPC NAT configured. Starting srsEPC ---"
exec srsepc /etc/srsran/epc.conf