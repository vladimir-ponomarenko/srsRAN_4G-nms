# srsRAN 4G NMS

## Quick Start

```bash
make build
make up
```
`make build` initializes submodules, prepares NETCONF keys, and builds all Docker images including srsRAN, EMS, libyang, libnetconf2, the C NETCONF server, and the test NETCONF client.


Stop environment:
```bash
make down
```

## Runtime Operations

### Common Commands

```bash
make logs-all     # follow all logs
make ue1-shell    # shell in UE-1
make ue2-shell    # shell in UE-2
make epc-shell    # shell in EPC
make restart      # down + up
```
Check more commands in Makefile

### Internet Reachability Check (both UEs)

```bash
make net-check
```

This runs `build/scripts/check_ue_internet.sh`, which validates:
- `tun_srsue` interface presence
- active routing table
- ping to external target (default `8.8.8.8`)

## NMS Integration (NETCONF/YANG)


### Access Details

Default NETCONF endpoints:

| Element | EMS container | Host endpoint |
| --- | --- | --- |
| ENB-1 | `EMS-ENB-1` | `127.0.0.1:8301` |
| ENB-2 | `EMS-ENB-2` | `127.0.0.1:8302` |

Default NETCONF SSH user:

```text
admin
```

The helper scripts normally execute `/app/netconf-client` inside the EMS container. That means you do not need to know the key paths manually for local testing.

### Read NETCONF Data

Read full data for example from ENB-1, including CM branch, PM metrics, and FM Active Alarm List:

```bash
NETCONF_EMS_CONTAINER=EMS-ENB-1 \
  bash build/scripts/netconf_poll.sh 127.0.0.1 8301 1 get-once
```

Read only running CM datastore:

```bash
NETCONF_EMS_CONTAINER=EMS-ENB-1 \
  bash build/scripts/netconf_poll.sh 127.0.0.1 8301 1 get-config-running
```

Read candidate CM datastore:

```bash
NETCONF_EMS_CONTAINER=EMS-ENB-1 \
  bash build/scripts/netconf_poll.sh 127.0.0.1 8301 1 get-config-candidate
```

Validate current candidate:

```bash
NETCONF_EMS_CONTAINER=EMS-ENB-1 \
  bash build/scripts/netconf_poll.sh 127.0.0.1 8301 1 validate-candidate
```

Discard candidate changes:

```bash
NETCONF_EMS_CONTAINER=EMS-ENB-1 \
  bash build/scripts/netconf_poll.sh 127.0.0.1 8301 1 discard-changes
```

Interactive mode
```bash
NETCONF_EMS_CONTAINER=EMS-ENB-1 \
  bash build/scripts/netconf_poll.sh 127.0.0.1 8301 1 interactive

# Then type several RPCs in the same SSH session:
get-config running
validate candidate
lock candidate
get-config candidate
unlock candidate
quit
```

### Control Management Test

The edit helper runs a real single-session NETCONF workflow:

```text
lock candidate -> lock running -> edit-config candidate -> validate candidate -> commit -> unlock running -> unlock candidate
```

Example: bar ENB-1 cell access.

```bash
NETCONF_EMS_CONTAINER=EMS-ENB-1 NETCONF_NRM_MANAGED_ELEMENT=enb1 \
  bash build/scripts/netconf_config_edit.sh 127.0.0.1 8301 cell_barred Barred commit
```

Restore access:

```bash
NETCONF_EMS_CONTAINER=EMS-ENB-1 NETCONF_NRM_MANAGED_ELEMENT=enb1 \
  bash build/scripts/netconf_config_edit.sh 127.0.0.1 8301 cell_barred NotBarred commit
```

Example: change channel bandwidth.

```bash
NETCONF_EMS_CONTAINER=EMS-ENB-1 NETCONF_NRM_MANAGED_ELEMENT=enb1 \
  bash build/scripts/netconf_config_edit.sh 127.0.0.1 8301 n_prb 50 commit
```

Example: stage a QCI list edit and discard it.

```bash
NETCONF_EMS_CONTAINER=EMS-ENB-1 NETCONF_NRM_MANAGED_ELEMENT=enb1 \
  bash build/scripts/netconf_config_edit.sh 127.0.0.1 8301 'qci_profiles[9].priority' 11 discard
```

### NETCONF RPC Quick Matrix

| Goal | Command |
| --- | --- |
| Full operational `<get>` once | `NETCONF_EMS_CONTAINER=EMS-ENB-1 bash build/scripts/netconf_poll.sh 127.0.0.1 8301 1 get-once` |
| Poll operational `<get>` | `NETCONF_EMS_CONTAINER=EMS-ENB-1 bash build/scripts/netconf_poll.sh 127.0.0.1 8301 5 get` |
| Full NRM branch once | `NETCONF_EMS_CONTAINER=EMS-ENB-1 bash build/scripts/netconf_poll.sh 127.0.0.1 8301 1 get-nrm-once` |
| Read running config | `NETCONF_EMS_CONTAINER=EMS-ENB-1 bash build/scripts/netconf_poll.sh 127.0.0.1 8301 1 get-config-running` |
| Read candidate config | `NETCONF_EMS_CONTAINER=EMS-ENB-1 bash build/scripts/netconf_poll.sh 127.0.0.1 8301 1 get-config-candidate` |
| Validate candidate | `NETCONF_EMS_CONTAINER=EMS-ENB-1 bash build/scripts/netconf_poll.sh 127.0.0.1 8301 1 validate-candidate` |
| Discard candidate | `NETCONF_EMS_CONTAINER=EMS-ENB-1 bash build/scripts/netconf_poll.sh 127.0.0.1 8301 1 discard-changes` |
| Subscribe to alarms | `NETCONF_EMS_CONTAINER=EMS-ENB-1 NETCONF_SUBSCRIBE_SECONDS=30 bash build/scripts/netconf_poll.sh 127.0.0.1 8301 1 subscribe-alarms` |
| Single-session edit/validate/commit | `NETCONF_EMS_CONTAINER=EMS-ENB-1 NETCONF_NRM_MANAGED_ELEMENT=enb1 bash build/scripts/netconf_config_edit.sh 127.0.0.1 8301 cell_barred Barred commit` |
| Single-session edit/validate/discard | `NETCONF_EMS_CONTAINER=EMS-ENB-1 NETCONF_NRM_MANAGED_ELEMENT=enb1 bash build/scripts/netconf_config_edit.sh 127.0.0.1 8301 cell_barred Barred discard` |

### NETCONF State Machine And Wrong-Order Behavior

NMS is allowed to send RPCs in any order. EMS never relies on a “happy path” sequence for safety.

The normal CM sequence is still:

```text
lock candidate -> lock running -> edit-config candidate -> validate candidate -> commit -> unlock running -> unlock candidate
```

But the following behavior is guaranteed:

| RPC | State | Expected response | Notes |
| --- | --- | --- | --- |
| `get` | any | `<data>...</data>` or empty data | Operational read, never mutates state. |
| `get-config running` | any | `<data>...</data>` | Running datastore read, never mutates state. |
| `get-config candidate` | any | `<data>...</data>` | Candidate datastore read, never mutates state. |
| `validate candidate` | candidate locked by another session | `<ok/>` or validation `<rpc-error>` | Read-only; lock does not block validation. |
| `lock candidate` | free | `<ok/>` | Owner becomes current NETCONF session-id. |
| `lock candidate` | already locked by same session | `<rpc-error><error-tag>lock-denied</error-tag>` | `error-info/session-id` identifies owner. |
| `lock candidate` | locked by another session | `<rpc-error><error-tag>lock-denied</error-tag>` | `error-info/session-id` identifies owner. |
| `unlock candidate` | unlocked | `<ok/>` | Safe no-op for “cleanup” clients. |
| `unlock candidate` | locked by owner | `<ok/>` | Candidate is reset to running. |
| `unlock candidate` | locked by another session | `<rpc-error><error-tag>operation-failed</error-tag>` | Ownership violation. |
| `edit-config candidate` | candidate free or locked by same session | `<ok/>` or validation `<rpc-error>` | Valid edits mutate candidate only. |
| `edit-config candidate` | candidate locked by another session | `<rpc-error><error-tag>in-use</error-tag>` | Candidate is not mutated. |
| `commit` | no pending candidate changes | `<ok/>` | No-op commit; no eNB restart. |
| `commit` | running locked by another session | `<rpc-error><error-tag>lock-denied</error-tag>` | Protects running datastore. |
| `commit` | candidate locked by another session | `<rpc-error><error-tag>in-use</error-tag>` | Candidate owner wins. |
| `discard-changes` | candidate free or locked by same session | `<ok/>` | Candidate is reset to running. |
| `discard-changes` | candidate locked by another session | `<rpc-error><error-tag>in-use</error-tag>` | Candidate is not mutated. |

Multiple NMS clients may connect concurrently.

- Concurrent read-only RPCs (`get`, `get-config`, `validate`) are allowed.
- Writes are serialized by datastore locks and Go-side mutexes.
- A dead SSH session cannot keep candidate locked forever: the C NETCONF server sends keepalives with active session IDs, and Go releases stale locks by TTL.
- On session close or stale-session cleanup, EMS discards uncommitted candidate edits owned by that session.
- On C NETCONF server restart, Go receives a session reset and clears all old NETCONF locks.

Example conflict test with two terminals:

```bash
# Terminal 1: keep a candidate lock in one persistent NETCONF session.
NETCONF_EMS_CONTAINER=EMS-ENB-1 \
  bash build/scripts/netconf_poll.sh 127.0.0.1 8301 1 hold-lock-candidate 60

# Terminal 2 while terminal 1 is still holding the SSH session:
NETCONF_EMS_CONTAINER=EMS-ENB-1 \
  bash build/scripts/netconf_poll.sh 127.0.0.1 8301 1 lock-candidate
```

Expected terminal 2 response:

```xml
<rpc-error>
  <error-tag>lock-denied</error-tag>
  <error-info>
    <session-id>...</session-id>
  </error-info>
</rpc-error>
```

### Fault Management Data Model

FM data is exposed in `ems-fault-management.yang` under the ENBFunction operational branch:

```text
SubNetwork/ManagedElement/ENBFunction/fault_management/active_alarm
```

Each active alarm has info:
- `alarm_id`
- `managed_object_instance`
- `event_type`
- `probable_cause`
- `perceived_severity`
- `specific_problem`
- `first_event_time`
- `last_event_time`
- `occurrence_count`

Only active alarms are kept in the AAL. Clear transitions are sent as NETCONF notifications and remove the record from the active list.

Supported alarms:

Metric-based alarms currently evaluated by TCA:

| Alarm | Metric condition | Severity | Event type |
| --- | --- | --- | --- |
| `Alarm_S1_Interface_Down` | `s1ap.ready < 1` | CRITICAL | CommunicationsAlarm |
| `Alarm_NAS_Signaling_Loss` | delta(`s1ap.nas_dl_drop + s1ap.nas_ul_fail`) > 0 | MAJOR | CommunicationsAlarm |
| `Alarm_NAS_Security_Mismatch` | delta(`s1ap.nas_ul_sec_hdr_unknown`) > 0 | MAJOR | ProcessingErrorAlarm |
| `Alarm_NAS_Parsing_Failure` | delta(`s1ap.nas_ul_parse_fail + s1ap.nas_dl_parse_fail`) > 0 | CRITICAL | ProcessingErrorAlarm |
| `Alarm_RRC_Protocol_Error` | delta(`rrc.rrc_protocol_fail`) > 0 | MAJOR | ProcessingErrorAlarm |
| `Alarm_RRC_Connection_Rejection` | delta(`rrc.rrc_con_reject_tx`) > 0, escalates to MAJOR above 5/window | MINOR/MAJOR | CommunicationsAlarm |
| `Alarm_Core_Service_Reject` | delta(`s1ap.nas_dl_service_reject`) > 0 | MAJOR | CommunicationsAlarm |
| `Alarm_Paging_Capacity_Exceeded` | delta(`rrc.rrc_paging_add_fail`) > 0 | MAJOR | CommunicationsAlarm |
| `Alarm_RLC_Max_Retransmissions` | delta(`rrc.rrc_max_rlc_retx`) > 0 | MAJOR | QualityOfServiceAlarm |
| `Alarm_Low_Throughput_Active_Users` | aggregate UE DL+UL bitrate < 1 Mbps while `rrc_connected_ues > 0` | MAJOR | QualityOfServiceAlarm |
| `Alarm_High_BLER` | max(`ue.dl_bler`, `ue.ul_bler`) > 0.10 | MAJOR | QualityOfServiceAlarm |
| `Alarm_Radio_Link_Failure_Storm` | delta(`ue.rrc_rlf_cnt`) > 5/window | CRITICAL | QualityOfServiceAlarm |
| `Alarm_Bad_Signal_Condition` | `ue.ul_snr < 0 dB` or `ue.dl_cqi < 5` | WARNING | QualityOfServiceAlarm |
| `Alarm_RF_Interference_Detected` | `ue.ul_pucch_ni > -90 dBm` | MAJOR | QualityOfServiceAlarm |
| `Alarm_UE_Inactivity_Cleanup` | high ratio of UE samples with `rrc_release_cause == inactivity` | WARNING | QualityOfServiceAlarm |
| `Alarm_Bearer_Congestion` | `bearer.<id>.dl_buffered_bytes > 500000` | MINOR | QualityOfServiceAlarm |
| `Alarm_Power_Headroom_Critical` | `ue.ul_phr <= 0` | WARNING | QualityOfServiceAlarm |

TCA thresholds are configured in `config/ems-agent/enb1.yaml` and `config/ems-agent/enb2.yaml`:

```yaml
pm:
  enabled: true
  granularity_period: 10s
  report_period: 10s

fm:
  tca:
    enabled: true
    test_injection_enabled: true
    rules:
      s1_interface_down:
        enabled: true
        raise_threshold: 1
        clear_threshold: 1
        raise_duration: 0s
        clear_duration: 10s
      nas_signaling_loss:
        enabled: true
        raise_threshold: 0
        clear_threshold: 0
        raise_duration: 0s
        clear_duration: 30s
      nas_security_mismatch:
        enabled: true
        raise_threshold: 0
        clear_threshold: 0
        raise_duration: 0s
        clear_duration: 30s
      nas_parsing_failure:
        enabled: true
        raise_threshold: 0
        clear_threshold: 0
        raise_duration: 0s
        clear_duration: 30s
      rrc_protocol_error:
        enabled: true
        raise_threshold: 0
        clear_threshold: 0
        raise_duration: 0s
        clear_duration: 30s
      low_throughput:
        enabled: true
        raise_threshold: 1000000
        clear_threshold: 1000001
        raise_duration: 30s
        clear_duration: 10s
      bad_signal_condition:
        enabled: true
        raise_threshold: 0
        clear_threshold: 5
        raise_duration: 10s
        clear_duration: 10s
      high_bler:
        enabled: true
        raise_threshold: 0.10
        clear_threshold: 0.05
        raise_duration: 10s
        clear_duration: 10s
```
### Pull FM: Query Active Alarm List

Query the current AAL:

```bash
NETCONF_EMS_CONTAINER=EMS-ENB-1 \
  bash build/scripts/netconf_poll.sh 127.0.0.1 8301 1 get-once | grep -E 'fault_management|active_alarm|Alarm_'
```

If there are no active alarms, `fault_management` can be empty or absent depending on the current snapshot timing.

### Push FM: Subscribe To NETCONF Notifications

Terminal 1: subscribe to ENB-1 alarm notifications for 30 seconds.

```bash
NETCONF_EMS_CONTAINER=EMS-ENB-1 NETCONF_SUBSCRIBE_SECONDS=30 \
  bash build/scripts/netconf_poll.sh 127.0.0.1 8301 1 subscribe-alarms
```

Terminal 2: inject a native srsENB-style alarm log event.

```bash
bash build/scripts/fm_inject_alarm.sh ENB-1 'S1 Setup failed: unknown PLMN'
```

Expected notification contains:

```xml
<alarm-notification xmlns="urn:ems:fault-management">
  <alarm_id>Alarm_S1_Down</alarm_id>
  <perceived_severity>CRITICAL</perceived_severity>
  <alarm_status>active</alarm_status>
</alarm-notification>
```

Clear the alarm:

```bash
bash build/scripts/fm_inject_alarm.sh ENB-1 'S1 setup cleared'
```

Expected notification contains:

```xml
<alarm_status>cleared</alarm_status>
<perceived_severity>CLEARED</perceived_severity>
```

After clear, the AAL query should no longer show that active alarm.


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
