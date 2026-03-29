# eNB Metrics JSON Schema (UDS)

Reference for the JSON payload emitted by `srsENB` over UDS.

## Root Object

| Field | JSON Type | C++ Type | Code Reference | Description | Notes / Values |
| --- | --- | --- | --- | --- | --- |
| `type` | string | `std::string` | `srsenb/src/metrics_json.cc` (metric_type_tag) | Message type identifier. | Always `"enb_metrics"`. |
| `enb_serial` | string | `std::string` | `srsenb/src/metrics_json.cc` (metric_enb_serial) | eNB serial identifier from config. | Free-form string. |
| `timestamp` | number (float) | `double` | `srsenb/src/metrics_json.cc` (metric_timestamp_tag) | UNIX timestamp in seconds with fractional part. | e.g., `1773771188.471`. |
| `s1ap_container` | object | `s1ap_metrics_t` | `srsenb/hdr/stack/s1ap/s1ap_metrics.h` | S1AP + NAS L3 metrics. | See `s1ap_container` section. |
| `rrc_container` | object | `rrc_metrics_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | Global RRC metrics (aggregated). | See `rrc_container` section. |
| `cell_list` | array | `std::vector<mset_cell_container>` | `srsenb/src/metrics_json.cc` (mlist_cell) | List of cells. | Each element is a `cell_container`. |

---

## s1ap_container

Source types and counters live in:
- `srsenb/hdr/stack/s1ap/s1ap_metrics.h`
- `srsenb/src/stack/s1ap/s1ap.cc` (collection)
- `srsenb/src/metrics_json.cc` (serialization)

| Field | JSON Type | C++ Type | Code Reference | Description | Notes / Values |
| --- | --- | --- | --- | --- | --- |
| `s1ap_status` | string | `S1AP_STATUS_ENUM` (stringified) | `srsenb/src/metrics_json.cc` (`s1ap_status_to_string`) | S1AP connection status. | `attaching`, `ready`, `error`. |
| `s1ap_status_code` | integer | `S1AP_STATUS_ENUM` | `srsenb/hdr/stack/s1ap/s1ap_metrics.h` | Numeric enum for S1AP status. | `0=attaching`, `1=ready`, `2=error`. |
| `nas_ul_msgs` | integer | `uint64_t` | `srsenb/hdr/stack/s1ap/s1ap_metrics.h` | Total NAS messages sent UL. | Counter. |
| `nas_ul_fail` | integer | `uint64_t` | `srsenb/hdr/stack/s1ap/s1ap_metrics.h` | UL NAS send failures. | Counter. |
| `nas_dl_msgs` | integer | `uint64_t` | `srsenb/hdr/stack/s1ap/s1ap_metrics.h` | Total NAS messages received DL. | Counter. |
| `nas_dl_drop` | integer | `uint64_t` | `srsenb/hdr/stack/s1ap/s1ap_metrics.h` | DL NAS drops due to internal errors. | Counter. |
| `nas_ul_bytes` | integer | `uint64_t` | `srsenb/hdr/stack/s1ap/s1ap_metrics.h` | Total UL NAS bytes. | Counter. |
| `nas_dl_bytes` | integer | `uint64_t` | `srsenb/hdr/stack/s1ap/s1ap_metrics.h` | Total DL NAS bytes. | Counter. |
| `nas_ul_transport_initial_ue` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` (update_nas_l3_counters) | UL NAS in InitialUEMessage. | Counter. |
| `nas_ul_transport_ul_nas` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` (update_nas_l3_counters) | UL NAS in UplinkNASTransport. | Counter. |
| `nas_dl_transport_dl_nas` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` (update_nas_l3_counters) | DL NAS in DownlinkNASTransport. | Counter. |
| `nas_ul_sec_hdr_plain` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL NAS with security header type PLAIN. | Counter. |
| `nas_ul_sec_hdr_integrity` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL NAS with integrity protection. | Counter. |
| `nas_ul_sec_hdr_integrity_ciphered` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL NAS integrity + ciphered. | Counter. |
| `nas_ul_sec_hdr_integrity_new_ctx` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL NAS integrity with new EPS security context. | Counter. |
| `nas_ul_sec_hdr_integrity_ciphered_new_ctx` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL NAS integrity + ciphered with new EPS security context. | Counter. |
| `nas_ul_sec_hdr_service_request` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL NAS Service Request (short MAC). | Counter. |
| `nas_ul_sec_hdr_unknown` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL NAS unknown security header. | Counter. |
| `nas_dl_sec_hdr_plain` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL NAS with security header type PLAIN. | Counter. |
| `nas_dl_sec_hdr_integrity` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL NAS with integrity protection. | Counter. |
| `nas_dl_sec_hdr_integrity_ciphered` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL NAS integrity + ciphered. | Counter. |
| `nas_dl_sec_hdr_integrity_new_ctx` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL NAS integrity with new EPS security context. | Counter. |
| `nas_dl_sec_hdr_integrity_ciphered_new_ctx` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL NAS integrity + ciphered with new EPS security context. | Counter. |
| `nas_dl_sec_hdr_service_request` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL NAS with Service Request sec hdr (normally 0). | Counter. |
| `nas_dl_sec_hdr_unknown` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL NAS unknown security header. | Counter. |
| `nas_ul_pd_emm` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL NAS protocol discriminator = EMM. | Counter. |
| `nas_ul_pd_esm` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL NAS protocol discriminator = ESM. | Counter. |
| `nas_ul_pd_other` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL NAS protocol discriminator not EMM/ESM. | Counter. |
| `nas_dl_pd_emm` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL NAS protocol discriminator = EMM. | Counter. |
| `nas_dl_pd_esm` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL NAS protocol discriminator = ESM. | Counter. |
| `nas_dl_pd_other` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL NAS protocol discriminator not EMM/ESM. | Counter. |
| `nas_ul_pd_last` | integer | `uint32_t` | `srsenb/src/stack/s1ap/s1ap.cc` | Last seen UL NAS PD (raw 4‑bit value). | Range `0..15`. |
| `nas_dl_pd_last` | integer | `uint32_t` | `srsenb/src/stack/s1ap/s1ap.cc` | Last seen DL NAS PD (raw 4‑bit value). | Range `0..15`. |
| `nas_ul_short_pdu` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL NAS short/empty PDU count. | Counter. |
| `nas_dl_short_pdu` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL NAS short/empty PDU count. | Counter. |
| `nas_ul_parse_fail` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL NAS parse failures. | Counter. |
| `nas_dl_parse_fail` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL NAS parse failures. | Counter. |
| `nas_ul_attach` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL Attach messages. | Counter. |
| `nas_dl_attach` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL Attach messages. | Counter. |
| `nas_ul_tau` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL Tracking Area Update messages. | Counter. |
| `nas_dl_tau` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL Tracking Area Update messages. | Counter. |
| `nas_ul_service_request` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL Service Requests (short MAC + Extended SR). | Counter. |
| `nas_dl_service_request` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL Service Request messages (usually 0). | Counter. |
| `nas_dl_service_reject` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL Service Reject messages. | Counter. |
| `nas_ul_identity` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL Identity messages. | Counter. |
| `nas_dl_identity` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL Identity messages. | Counter. |
| `nas_ul_authentication` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL Authentication messages. | Counter. |
| `nas_dl_authentication` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL Authentication messages. | Counter. |
| `nas_ul_security_mode` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL Security Mode messages. | Counter. |
| `nas_dl_security_mode` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL Security Mode messages. | Counter. |
| `nas_ul_detach` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL Detach messages. | Counter. |
| `nas_dl_detach` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL Detach messages. | Counter. |
| `nas_ul_emm_status` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL EMM Status messages. | Counter. |
| `nas_dl_emm_status` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL EMM Status messages. | Counter. |
| `nas_ul_esm_information` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL ESM Information messages. | Counter. |
| `nas_dl_esm_information` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL ESM Information messages. | Counter. |
| `nas_ul_pdn_connectivity` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL PDN Connectivity messages. | Counter. |
| `nas_dl_pdn_connectivity` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL PDN Connectivity messages. | Counter. |
| `nas_ul_pdn_disconnect` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL PDN Disconnect messages. | Counter. |
| `nas_dl_pdn_disconnect` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL PDN Disconnect messages. | Counter. |
| `nas_ul_default_bearer` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL Default Bearer activation messages. | Counter. |
| `nas_dl_default_bearer` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL Default Bearer activation messages. | Counter. |
| `nas_ul_dedicated_bearer` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL Dedicated Bearer activation messages. | Counter. |
| `nas_dl_dedicated_bearer` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL Dedicated Bearer activation messages. | Counter. |
| `nas_ul_modify_bearer` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL Modify Bearer messages. | Counter. |
| `nas_dl_modify_bearer` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL Modify Bearer messages. | Counter. |
| `nas_ul_deactivate_bearer` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL Deactivate Bearer messages. | Counter. |
| `nas_dl_deactivate_bearer` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL Deactivate Bearer messages. | Counter. |
| `nas_ul_bearer_resource` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL Bearer Resource Allocation/Modification messages. | Counter. |
| `nas_dl_bearer_resource` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL Bearer Resource Allocation/Modification messages. | Counter. |
| `nas_ul_generic_transport` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL Generic NAS Transport messages. | Counter. |
| `nas_dl_generic_transport` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL Generic NAS Transport messages. | Counter. |
| `nas_dl_cs_service_notification` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL CS Service Notification (CSFB / voice). | Counter. |
| `nas_ul_other` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL NAS message types parsed but not classified above. | Counter. |
| `nas_dl_other` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL NAS message types parsed but not classified above. | Counter. |
| `nas_ul_unknown` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | UL NAS parse failures for message type. | Counter. |
| `nas_dl_unknown` | integer | `uint64_t` | `srsenb/src/stack/s1ap/s1ap.cc` | DL NAS parse failures for message type. | Counter. |

---

## rrc_container (Global)

Source types and counters live in:
- `srsenb/hdr/stack/rrc/rrc_metrics.h`
- `srsenb/src/stack/rrc/rrc.cc` (collection)
- `srsenb/src/metrics_json.cc` (serialization)

| Field | JSON Type | C++ Type | Code Reference | Description | Notes / Values |
| --- | --- | --- | --- | --- | --- |
| `rrc_total_ues` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | Total UEs in RRC database. | Counter. |
| `rrc_connected_ues` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | UEs in CONNECTED state. | Counter. |
| `rrc_con_req_rx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RRC Connection Request received. | Counter. |
| `rrc_con_setup_tx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RRC Connection Setup sent. | Counter. |
| `rrc_con_setup_complete_rx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RRC Connection Setup Complete received. | Counter. |
| `rrc_con_reject_tx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RRC Connection Reject sent. | Counter. |
| `rrc_con_reest_req_rx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RRC Connection Reestablishment Request received. | Counter. |
| `rrc_con_reest_tx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RRC Connection Reestablishment sent. | Counter. |
| `rrc_con_reest_complete_rx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RRC Connection Reestablishment Complete received. | Counter. |
| `rrc_con_reest_reject_tx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RRC Connection Reestablishment Reject sent. | Counter. |
| `rrc_con_reconf_tx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RRC Connection Reconfiguration sent. | Counter. |
| `rrc_con_reconf_complete_rx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RRC Connection Reconfiguration Complete received. | Counter. |
| `rrc_con_release_tx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RRC Connection Release sent. | Counter. |
| `rrc_security_mode_command_tx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RRC Security Mode Command sent. | Counter. |
| `rrc_security_mode_complete_rx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RRC Security Mode Complete received. | Counter. |
| `rrc_security_mode_failure_rx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RRC Security Mode Failure received. | Counter. |
| `rrc_ue_cap_enquiry_tx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | UE Capability Enquiry sent. | Counter. |
| `rrc_ue_cap_info_rx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | UE Capability Information received. | Counter. |
| `rrc_ue_info_req_tx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | UE Information Request sent. | Counter. |
| `rrc_ue_info_resp_rx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | UE Information Response received. | Counter. |
| `rrc_max_rlc_retx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RLC max retransmissions reached. | Counter. |
| `rrc_protocol_fail` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RRC protocol failures. | Counter. |
| `rrc_paging_requests_total` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | Total paging requests received. | Counter. |
| `rrc_paging_imsi` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | Paging with IMSI identity. | Counter. |
| `rrc_paging_tmsi` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | Paging with TMSI identity. | Counter. |
| `rrc_paging_add_fail` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | Paging add failures. | Counter. |
| `rrc_paging_pdu_tx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | Paging PDUs sent. | Counter. |
| `rrc_paging_bytes_tx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | Paging bytes sent. | Counter. |
| `rrc_paging_identities_tx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | Paging identities sent. | Counter. |
| `rrc_pdcp_integrity_errors` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | PDCP integrity errors. | Counter. |
| `rrc_state_idle` | integer | `uint32_t` | `srsenb/src/metrics_json.cc` | UEs in IDLE state. | Counter. |
| `rrc_state_wait_for_con_setup_complete` | integer | `uint32_t` | `srsenb/src/metrics_json.cc` | UEs waiting for Conn Setup Complete. | Counter. |
| `rrc_state_wait_for_con_reest_complete` | integer | `uint32_t` | `srsenb/src/metrics_json.cc` | UEs waiting for Conn Reest Complete. | Counter. |
| `rrc_state_wait_for_security_mode_complete` | integer | `uint32_t` | `srsenb/src/metrics_json.cc` | UEs waiting for Security Mode Complete. | Counter. |
| `rrc_state_wait_for_ue_cap_info` | integer | `uint32_t` | `srsenb/src/metrics_json.cc` | UEs waiting for UE Capability Info. | Counter. |
| `rrc_state_wait_for_ue_cap_info_endc` | integer | `uint32_t` | `srsenb/src/metrics_json.cc` | UEs waiting for UE Capability Info ENDC. | Counter. |
| `rrc_state_wait_for_con_reconf_complete` | integer | `uint32_t` | `srsenb/src/metrics_json.cc` | UEs waiting for Conn Reconf Complete. | Counter. |
| `rrc_state_reestablishment_complete` | integer | `uint32_t` | `srsenb/src/metrics_json.cc` | UEs in Reestablishment Complete. | Counter. |
| `rrc_state_registered` | integer | `uint32_t` | `srsenb/src/metrics_json.cc` | UEs in Registered state. | Counter. |
| `rrc_state_release_request` | integer | `uint32_t` | `srsenb/src/metrics_json.cc` | UEs in Release Request state. | Counter. |

---

## cell_container (per cell)

| Field | JSON Type | C++ Type | Code Reference | Description | Notes / Values |
| --- | --- | --- | --- | --- | --- |
| `carrier_id` | integer | `uint32_t` | `srsenb/src/metrics_json.cc` | Carrier ID. | `0..N-1`. |
| `pci` | integer | `uint32_t` | `srsenb/src/metrics_json.cc` | Physical Cell ID. | `0..503`. |
| `nof_rach` | integer | `uint32_t` | `srsenb/src/metrics_json.cc` | Random access attempts observed. | Counter. |
| `ue_list` | array | `std::vector<mset_ue_container>` | `srsenb/src/metrics_json.cc` | List of UE containers. | Each element is a `ue_container`. |

---

## ue_container (per UE)

Source types and counters live in:
- `srsenb/hdr/stack/rrc/rrc_metrics.h`
- `srsenb/src/stack/rrc/rrc_ue.cc` (collection)
- `srsenb/src/metrics_json.cc` (serialization)

| Field | JSON Type | C++ Type | Code Reference | Description | Notes / Values |
| --- | --- | --- | --- | --- | --- |
| `ue_rnti` | integer | `uint16_t` | `srsenb/src/metrics_json.cc` | UE RNTI. | Hex in logs, decimal in JSON. |
| `dl_cqi` | number | `float` | `srsenb/src/metrics_json.cc` | DL CQI. | float. |
| `dl_mcs` | number | `float` | `srsenb/src/metrics_json.cc` | DL MCS. | float. |
| `dl_bitrate` | number | `float` | `srsenb/src/metrics_json.cc` | DL bitrate. | bits/s. |
| `dl_bler` | number | `float` | `srsenb/src/metrics_json.cc` | DL BLER. | 0..1. |
| `ul_snr` | number | `float` | `srsenb/src/metrics_json.cc` | UL SNR. | float. |
| `ul_mcs` | number | `float` | `srsenb/src/metrics_json.cc` | UL MCS. | float. |
| `ul_pusch_rssi` | number | `float` | `srsenb/src/metrics_json.cc` | UL PUSCH RSSI. | float. |
| `ul_pucch_rssi` | number | `float` | `srsenb/src/metrics_json.cc` | UL PUCCH RSSI. | float. |
| `ul_pucch_ni` | number | `float` | `srsenb/src/metrics_json.cc` | UL PUCCH noise/interference. | float. |
| `ul_pusch_tpc` | integer | `int64_t` | `srsenb/src/metrics_json.cc` | UL PUSCH TPC. | int64. |
| `ul_pucch_tpc` | integer | `int64_t` | `srsenb/src/metrics_json.cc` | UL PUCCH TPC. | int64. |
| `dl_cqi_offset` | number | `float` | `srsenb/src/metrics_json.cc` | DL CQI offset. | float. |
| `ul_snr_offset` | number | `float` | `srsenb/src/metrics_json.cc` | UL SNR offset. | float. |
| `ul_bitrate` | number | `float` | `srsenb/src/metrics_json.cc` | UL bitrate. | bits/s. |
| `ul_bler` | number | `float` | `srsenb/src/metrics_json.cc` | UL BLER. | 0..1. |
| `ul_phr` | number | `float` | `srsenb/src/metrics_json.cc` | UL PHR. | float. |
| `ul_bsr` | integer | `uint32_t` | `srsenb/src/metrics_json.cc` | UL BSR. | bytes. |
| `rrc_state_str` | string | `rrc_state_t` (stringified) | `srsenb/src/metrics_json.cc` (`rrc_state_to_string`) | RRC state (string). | See mapping below. |
| `rrc_state` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RRC state (numeric). | `0..9`. |
| `rrc_drb_count` | integer | `size_t` | `srsenb/src/metrics_json.cc` | Number of active DRBs. | Counter. |
| `rrc_nof_cells` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | Number of configured cells for UE. | Counter. |
| `rrc_is_allocated` | integer | `bool` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | UE allocated in RRC. | `0/1`. |
| `rrc_sr_res_present` | integer | `bool` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | SR resources allocated. | `0/1`. |
| `rrc_n_pucch_cs_present` | integer | `bool` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | PUCCH CS allocated. | `0/1`. |
| `rrc_is_csfb` | integer | `bool` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | CSFB enabled for UE. | `0/1`. |
| `rrc_connect_notified` | integer | `bool` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | Connected notification sent. | `0/1`. |
| `rrc_rlf_cnt` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RLF count. | Counter. |
| `rrc_rlf_info_pending` | integer | `bool` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RLF info pending. | `0/1`. |
| `rrc_consecutive_kos_dl` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | Consecutive DL KOs. | Counter. |
| `rrc_consecutive_kos_ul` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | Consecutive UL KOs. | Counter. |
| `rrc_has_tmsi` | integer | `bool` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | UE has TMSI. | `0/1`. |
| `rrc_m_tmsi` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | UE M‑TMSI. | 32‑bit. |
| `rrc_mmec` | integer | `uint8_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | MMEC. | 8‑bit. |
| `rrc_establishment_cause` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RRC establishment cause. | Enum numeric. |
| `rrc_transaction_id` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | Last RRC transaction id. | `0..3`. |
| `rrc_activity_timer_running` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | Activity timer running. | `0/1`. |
| `rrc_activity_timer_elapsed` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | Activity timer elapsed (ms). | integer. |
| `rrc_activity_timer_duration` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | Activity timer duration (ms). | integer. |
| `rrc_phy_dl_rlf_timer_running` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | PHY DL RLF timer running. | `0/1`. |
| `rrc_phy_dl_rlf_timer_elapsed` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | PHY DL RLF elapsed (ms). | integer. |
| `rrc_phy_dl_rlf_timer_duration` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | PHY DL RLF duration (ms). | integer. |
| `rrc_phy_ul_rlf_timer_running` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | PHY UL RLF timer running. | `0/1`. |
| `rrc_phy_ul_rlf_timer_elapsed` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | PHY UL RLF elapsed (ms). | integer. |
| `rrc_phy_ul_rlf_timer_duration` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | PHY UL RLF duration (ms). | integer. |
| `rrc_rlc_rlf_timer_running` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RLC RLF timer running. | `0/1`. |
| `rrc_rlc_rlf_timer_elapsed` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RLC RLF elapsed (ms). | integer. |
| `rrc_rlc_rlf_timer_duration` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RLC RLF duration (ms). | integer. |
| `rrc_last_ul_msg_bytes` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | Last UL RRC message size. | bytes. |
| `rrc_eutra_capabilities_unpacked` | integer | `bool` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | UE capabilities decoded. | `0/1`. |
| `rrc_release_cause` | string | `std::string` | `srsenb/src/stack/rrc/rrc_ue.cc` | Last RRC release cause. | e.g., `other`. |
| `rrc_con_req_rx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RRC Conn Request count. | Counter. |
| `rrc_con_setup_tx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RRC Conn Setup count. | Counter. |
| `rrc_con_setup_complete_rx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RRC Conn Setup Complete count. | Counter. |
| `rrc_con_reject_tx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RRC Conn Reject count. | Counter. |
| `rrc_con_reest_req_rx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RRC Reest Req count. | Counter. |
| `rrc_con_reest_tx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RRC Reest Tx count. | Counter. |
| `rrc_con_reest_complete_rx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RRC Reest Complete count. | Counter. |
| `rrc_con_reest_reject_tx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RRC Reest Reject count. | Counter. |
| `rrc_con_reconf_tx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RRC Reconf Tx count. | Counter. |
| `rrc_con_reconf_complete_rx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RRC Reconf Complete count. | Counter. |
| `rrc_con_release_tx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RRC Release Tx count. | Counter. |
| `rrc_security_mode_command_tx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | Security Mode Command Tx count. | Counter. |
| `rrc_security_mode_complete_rx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | Security Mode Complete Rx count. | Counter. |
| `rrc_security_mode_failure_rx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | Security Mode Failure Rx count. | Counter. |
| `rrc_ue_cap_enquiry_tx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | UE Cap Enquiry Tx count. | Counter. |
| `rrc_ue_cap_info_rx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | UE Cap Info Rx count. | Counter. |
| `rrc_ue_info_req_tx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | UE Info Req Tx count. | Counter. |
| `rrc_ue_info_resp_rx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | UE Info Resp Rx count. | Counter. |
| `rrc_max_rlc_retx` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RLC max retx hit. | Counter. |
| `rrc_protocol_fail` | integer | `uint32_t` | `srsenb/hdr/stack/rrc/rrc_metrics.h` | RRC protocol failures. | Counter. |
| `bearer_list` | array | `std::vector<mset_bearer_container>` | `srsenb/src/metrics_json.cc` | List of bearer containers. | Each element is a `bearer_container`. |

**RRC state mapping**

| rrc_state | rrc_state_str |
| --- | --- |
| 0 | `idle` |
| 1 | `wait_for_con_setup_complete` |
| 2 | `wait_for_con_reest_complete` |
| 3 | `wait_for_security_mode_complete` |
| 4 | `wait_for_ue_cap_info` |
| 5 | `wait_for_ue_cap_info_endc` |
| 6 | `wait_for_con_reconf_complete` |
| 7 | `reestablishment_complete` |
| 8 | `registered` |
| 9 | `release_request` |

---

## bearer_container (per bearer)

| Field | JSON Type | C++ Type | Code Reference | Description | Notes / Values |
| --- | --- | --- | --- | --- | --- |
| `bearer_id` | integer | `uint32_t` | `srsenb/src/metrics_json.cc` | Bearer ID. | `0..15`. |
| `qci` | integer | `uint32_t` | `srsenb/src/metrics_json.cc` | QCI value. | 1..9. |
| `dl_total_bytes` | integer | `uint64_t` | `srsenb/src/metrics_json.cc` | DL total bytes. | Counter. |
| `ul_total_bytes` | integer | `uint64_t` | `srsenb/src/metrics_json.cc` | UL total bytes. | Counter. |
| `dl_latency` | number | `float` | `srsenb/src/metrics_json.cc` | DL latency estimate. | float. |
| `ul_latency` | number | `float` | `srsenb/src/metrics_json.cc` | UL latency estimate. | float. |
| `dl_buffered_bytes` | integer | `uint32_t` | `srsenb/src/metrics_json.cc` | DL buffered bytes. | Counter. |
| `ul_buffered_bytes` | integer | `uint32_t` | `srsenb/src/metrics_json.cc` | UL buffered bytes. | Counter. |

# Json Example (zmq)
```json
{
  "type": "enb_metrics",
  "enb_serial": "ENB-0x19B-001-01-SibSutis&Yadro",
  "timestamp": 1773771187.471,
  "s1ap_container": {
    "s1ap_status": "ready",
    "s1ap_status_code": 1,
    "nas_ul_msgs": 6,
    "nas_ul_fail": 0,
    "nas_dl_msgs": 4,
    "nas_dl_drop": 0,
    "nas_ul_bytes": 79,
    "nas_dl_bytes": 103,
    "nas_ul_transport_initial_ue": 2,
    "nas_ul_transport_ul_nas": 4,
    "nas_dl_transport_dl_nas": 4,
    "nas_ul_sec_hdr_plain": 2,
    "nas_ul_sec_hdr_integrity": 1,
    "nas_ul_sec_hdr_integrity_ciphered": 1,
    "nas_ul_sec_hdr_integrity_new_ctx": 0,
    "nas_ul_sec_hdr_integrity_ciphered_new_ctx": 1,
    "nas_ul_sec_hdr_service_request": 1,
    "nas_ul_sec_hdr_unknown": 0,
    "nas_dl_sec_hdr_plain": 2,
    "nas_dl_sec_hdr_integrity": 0,
    "nas_dl_sec_hdr_integrity_ciphered": 1,
    "nas_dl_sec_hdr_integrity_new_ctx": 1,
    "nas_dl_sec_hdr_integrity_ciphered_new_ctx": 0,
    "nas_dl_sec_hdr_service_request": 0,
    "nas_dl_sec_hdr_unknown": 0,
    "nas_ul_pd_emm": 0,
    "nas_ul_pd_esm": 0,
    "nas_ul_pd_other": 6,
    "nas_dl_pd_emm": 0,
    "nas_dl_pd_esm": 0,
    "nas_dl_pd_other": 4,
    "nas_ul_pd_last": 0,
    "nas_dl_pd_last": 0,
    "nas_ul_short_pdu": 0,
    "nas_dl_short_pdu": 0,
    "nas_ul_parse_fail": 0,
    "nas_dl_parse_fail": 0,
    "nas_ul_attach": 1,
    "nas_dl_attach": 0,
    "nas_ul_tau": 0,
    "nas_dl_tau": 0,
    "nas_ul_service_request": 1,
    "nas_dl_service_request": 0,
    "nas_dl_service_reject": 0,
    "nas_ul_identity": 1,
    "nas_dl_identity": 1,
    "nas_ul_authentication": 1,
    "nas_dl_authentication": 1,
    "nas_ul_security_mode": 0,
    "nas_dl_security_mode": 1,
    "nas_ul_detach": 0,
    "nas_dl_detach": 0,
    "nas_ul_emm_status": 0,
    "nas_dl_emm_status": 0,
    "nas_ul_esm_information": 0,
    "nas_dl_esm_information": 0,
    "nas_ul_pdn_connectivity": 0,
    "nas_dl_pdn_connectivity": 0,
    "nas_ul_pdn_disconnect": 0,
    "nas_dl_pdn_disconnect": 0,
    "nas_ul_default_bearer": 0,
    "nas_dl_default_bearer": 0,
    "nas_ul_dedicated_bearer": 0,
    "nas_dl_dedicated_bearer": 0,
    "nas_ul_modify_bearer": 0,
    "nas_dl_modify_bearer": 0,
    "nas_ul_deactivate_bearer": 0,
    "nas_dl_deactivate_bearer": 0,
    "nas_ul_bearer_resource": 0,
    "nas_dl_bearer_resource": 0,
    "nas_ul_generic_transport": 0,
    "nas_dl_generic_transport": 0,
    "nas_dl_cs_service_notification": 0,
    "nas_ul_other": 0,
    "nas_dl_other": 0,
    "nas_ul_unknown": 0,
    "nas_dl_unknown": 0
  },
  "rrc_container": {
    "rrc_total_ues": 1,
    "rrc_connected_ues": 1,
    "rrc_con_req_rx": 1,
    "rrc_con_setup_tx": 1,
    "rrc_con_setup_complete_rx": 1,
    "rrc_con_reject_tx": 0,
    "rrc_con_reest_req_rx": 0,
    "rrc_con_reest_tx": 0,
    "rrc_con_reest_complete_rx": 0,
    "rrc_con_reest_reject_tx": 0,
    "rrc_con_reconf_tx": 1,
    "rrc_con_reconf_complete_rx": 1,
    "rrc_con_release_tx": 0,
    "rrc_security_mode_command_tx": 1,
    "rrc_security_mode_complete_rx": 1,
    "rrc_security_mode_failure_rx": 0,
    "rrc_ue_cap_enquiry_tx": 1,
    "rrc_ue_cap_info_rx": 1,
    "rrc_ue_info_req_tx": 0,
    "rrc_ue_info_resp_rx": 0,
    "rrc_max_rlc_retx": 0,
    "rrc_protocol_fail": 0,
    "rrc_paging_requests_total": 1,
    "rrc_paging_imsi": 0,
    "rrc_paging_tmsi": 1,
    "rrc_paging_add_fail": 0,
    "rrc_paging_pdu_tx": 1,
    "rrc_paging_bytes_tx": 7,
    "rrc_paging_identities_tx": 1,
    "rrc_pdcp_integrity_errors": 0,
    "rrc_state_idle": 0,
    "rrc_state_wait_for_con_setup_complete": 0,
    "rrc_state_wait_for_con_reest_complete": 0,
    "rrc_state_wait_for_security_mode_complete": 0,
    "rrc_state_wait_for_ue_cap_info": 0,
    "rrc_state_wait_for_ue_cap_info_endc": 0,
    "rrc_state_wait_for_con_reconf_complete": 0,
    "rrc_state_reestablishment_complete": 0,
    "rrc_state_registered": 1,
    "rrc_state_release_request": 0
  },
  "cell_list": [
    {
      "cell_container": {
        "carrier_id": 0,
        "pci": 1,
        "nof_rach": 2,
        "ue_list": [
          {
            "ue_container": {
              "ue_rnti": 71,
              "dl_cqi": 15.0,
              "dl_mcs": 15.0,
              "ul_pusch_rssi": 86.28583,
              "ul_pucch_rssi": 82.28867,
              "ul_pucch_ni": 124.52872,
              "ul_pusch_tpc": 0,
              "ul_pucch_tpc": 0,
              "dl_cqi_offset": 0.010000001,
              "ul_snr_offset": 0.014000001,
              "dl_bitrate": 887.0116,
              "dl_bler": 0.0,
              "ul_snr": 115.0247,
              "ul_mcs": 14.0,
              "ul_bitrate": 4620.908,
              "ul_bler": 0.0,
              "ul_phr": 30.0,
              "ul_bsr": 0,
              "rrc_state_str": "registered",
              "rrc_state": 8,
              "rrc_drb_count": 1,
              "rrc_nof_cells": 1,
              "rrc_is_allocated": 1,
              "rrc_sr_res_present": 1,
              "rrc_n_pucch_cs_present": 0,
              "rrc_is_csfb": 0,
              "rrc_connect_notified": 0,
              "rrc_rlf_cnt": 0,
              "rrc_rlf_info_pending": 0,
              "rrc_consecutive_kos_dl": 0,
              "rrc_consecutive_kos_ul": 0,
              "rrc_has_tmsi": 1,
              "rrc_m_tmsi": 3043248320,
              "rrc_mmec": 26,
              "rrc_establishment_cause": 2,
              "rrc_transaction_id": 0,
              "rrc_activity_timer_running": 1,
              "rrc_activity_timer_elapsed": 344,
              "rrc_activity_timer_duration": 30000,
              "rrc_phy_dl_rlf_timer_running": 0,
              "rrc_phy_dl_rlf_timer_elapsed": 0,
              "rrc_phy_dl_rlf_timer_duration": 4000,
              "rrc_phy_ul_rlf_timer_running": 0,
              "rrc_phy_ul_rlf_timer_elapsed": 0,
              "rrc_phy_ul_rlf_timer_duration": 4000,
              "rrc_rlc_rlf_timer_running": 0,
              "rrc_rlc_rlf_timer_elapsed": 0,
              "rrc_rlc_rlf_timer_duration": 4000,
              "rrc_last_ul_msg_bytes": 2,
              "rrc_eutra_capabilities_unpacked": 1,
              "rrc_release_cause": "other",
              "rrc_con_req_rx": 1,
              "rrc_con_setup_tx": 1,
              "rrc_con_setup_complete_rx": 1,
              "rrc_con_reject_tx": 0,
              "rrc_con_reest_req_rx": 0,
              "rrc_con_reest_tx": 0,
              "rrc_con_reest_complete_rx": 0,
              "rrc_con_reest_reject_tx": 0,
              "rrc_con_reconf_tx": 1,
              "rrc_con_reconf_complete_rx": 1,
              "rrc_con_release_tx": 0,
              "rrc_security_mode_command_tx": 1,
              "rrc_security_mode_complete_rx": 1,
              "rrc_security_mode_failure_rx": 0,
              "rrc_ue_cap_enquiry_tx": 1,
              "rrc_ue_cap_info_rx": 1,
              "rrc_ue_info_req_tx": 0,
              "rrc_ue_info_resp_rx": 0,
              "rrc_max_rlc_retx": 0,
              "rrc_protocol_fail": 0,
              "bearer_list": [
                {
                  "bearer_container": {
                    "bearer_id": 3,
                    "qci": 7,
                    "dl_total_bytes": 258,
                    "ul_total_bytes": 258,
                    "dl_latency": 0.0,
                    "ul_latency": 0.0,
                    "dl_buffered_bytes": 0,
                    "ul_buffered_bytes": 0
                  }
                }
              ]
            }
          }
        ]
      }
    }
  ]
}
```

## NETCONF encoding note

For NETCONF payloads we follow RFC7951 encoding rules. That means any `uint64`
fields are serialized as strings in the NETCONF snapshot (even though the raw
UDS JSON contains numeric values). This applies to:

- `s1ap_container.nas_*` counters
- `bearer_container.dl_total_bytes`, `bearer_container.ul_total_bytes`
