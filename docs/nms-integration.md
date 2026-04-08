# NMS Integration (NETCONF/YANG)

Each EMS exposes a NETCONF-over-SSH endpoint that serves:

- Legacy metrics container: `ems-enb-metrics:enb_metrics`
- NRM/PM tree: `_3gpp-common-managed-element:SubNetwork/ManagedElement/ENBFunction/EUtranCell/measurements`
- Vendor augmentation: `srsran-vendor-ext:srsran/enb_metrics` under `ENBFunction`

## Endpoints / Ports

Docker Compose publishes NETCONF ports to the host:

- ENB-1 EMS: `127.0.0.1:8301`
- ENB-2 EMS: `127.0.0.1:8302`

Or on another machine, connect to `<docker-host-ip>:8301` / `:8302`.

## Authentication

NETCONF transport is SSH public key auth.

- Username: `admin`
- Client private key (demo): `netconf/keys/client_key`
- Server authorized keys (demo): `netconf/keys/authorized_keys`
- Known hosts file (client-side): `netconf/known_hosts`

Key generation:

```bash
make netconf-keys
```

This generates keys under `externals/lte-element-manager/netconf/keys` and exports them to `netconf/keys` (which is `.gitignore`'d).

## What To Query (NRM/PM)

- SubNetwork: `srsRAN`
- ManagedElement: `enb1` / `enb2`
- ENBFunction: `1`
- EUtranCell: assigned inside each EMS instance (e.g. `"1"`, `"2"`, ...)

### XPath (recommended, module-aware)

XPaths:

```text
/cme:SubNetwork[cme:id='srsRAN']
  /cme:ManagedElement[cme:id='enb1']
  /cme:ENBFunction[cme:id='1']
```

EUtranCell list (all cells):

```text
/cme:SubNetwork[cme:id='srsRAN']
  /cme:ManagedElement[cme:id='enb1']
  /cme:ENBFunction[cme:id='1']
  /cme:EUtranCell
```

Measurements only:

```text
/cme:SubNetwork[cme:id='srsRAN']
  /cme:ManagedElement[cme:id='enb1']
  /cme:ENBFunction[cme:id='1']
  /cme:EUtranCell[cme:id='1']
  /cme:measurements
```

Vendor telemetry (full srsRAN payload, augmented under ENBFunction):

```text
/cme:SubNetwork[cme:id='srsRAN']
  /cme:ManagedElement[cme:id='enb1']
  /cme:ENBFunction[cme:id='1']
  /srs:srsran
```

Prefixes/namespaces:

- `cme` = `urn:3gpp:sa5:_3gpp-common-managed-element`
- `srs` = `urn:vendor:srsran:ext`
- `ems` = `urn:ems:enb:metrics`

### XPath for the bundled poll script (prefixless)

`build/scripts/netconf_poll.sh` uses the libnetconf2 *example* client, which does not validate custom prefixes locally, so it uses prefixless XPath:

```text
/*[local-name()='SubNetwork'][*[local-name()='id']='srsRAN']
  /*[local-name()='ManagedElement'][*[local-name()='id']='enb1']
  /*[local-name()='ENBFunction'][*[local-name()='id']='1']
```

Cells:

```text
/*[local-name()='SubNetwork'][*[local-name()='id']='srsRAN']
  /*[local-name()='ManagedElement'][*[local-name()='id']='enb1']
  /*[local-name()='ENBFunction'][*[local-name()='id']='1']
  /*[local-name()='EUtranCell']
```

## Quick Commands (local dev)

```bash
make POLL_INTERVAL=2 netconf-poll-enb1-nrm
make POLL_INTERVAL=2 netconf-poll-enb1-nrm-cells
make POLL_INTERVAL=2 netconf-poll-enb2-nrm
make POLL_INTERVAL=2 netconf-poll-enb2-nrm-cells
```

To fetch the legacy container:

```bash
make POLL_INTERVAL=2 netconf-poll-enb1
make POLL_INTERVAL=2 netconf-poll-enb2
```
