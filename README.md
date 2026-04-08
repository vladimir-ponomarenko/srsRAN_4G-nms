# srsRAN 4G NMS

## NMS Integration (NETCONF/YANG)

NETCONF endpoints (published to host):

- ENB-1 EMS: `127.0.0.1:8301`
- ENB-2 EMS: `127.0.0.1:8302`

Auth:

- SSH user: `admin`
- Keys are generated via `make netconf-keys` and exported to `netconf/keys` (not committed).

NRM/PM polling examples:

```bash
make POLL_INTERVAL=2 netconf-poll-enb1-nrm
make POLL_INTERVAL=2 netconf-poll-enb1-nrm-cells
```

Full details (ports, keys, XPath filters, vendor augmentation):

- [docs/nms-integration.md](docs/nms-integration.md)

## Quick Start

```bash
make build
make up
```



Stop environment:
```bash
make down
```

## Runtime Operations

### Common Commands

```bash
make logs         # follow ENB-1 logs
make ue1-shell    # shell in UE-1
make ue2-shell    # shell in UE-2
make epc-shell    # shell in EPC
make restart      # down + up
```

### Internet Reachability Check (both UEs)

```bash
make net-check
```

This runs `build/scripts/check_ue_internet.sh`, which validates:
- `tun_srsue` interface presence
- active routing table
- ping to external target (default `8.8.8.8`)

## Network and Traffic Model

### EPC Egress

`build/scripts/epc_entrypoint.sh` performs:
- `net.ipv4.ip_forward=1`
- `iptables -t nat -A POSTROUTING -s 172.16.0.0/24 -o eth0 -j MASQUERADE`

Result: UE subnet can reach external networks through EPC.

### UE Routing

`build/scripts/ue_entrypoint.sh` performs:
- start `srsue`
- wait until `tun_srsue` is created and has IPv4
- set default route via EPC gateway `172.16.0.1`

Result: UE traffic uses LTE path instead of Docker default route.


## License

See [LICENSE](LICENSE).
