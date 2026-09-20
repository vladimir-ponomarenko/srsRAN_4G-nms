/*
 * E2 metrics xApp for the EMS: aggregates every O-RAN E2SM indication produced
 * by an OAI 5G gNB (E2SM-MAC, E2SM-RLC, E2SM-PDCP, E2SM-GTP and O-RAN
 * E2SM-KPM) and exports the NR telemetry envelope the EMS FCAPS pipeline
 * consumes.
 *
 *
 * SPDX-License-Identifier: LicenseRef-CSSL-1.0
 */

#include "ems_metrics_json.h"
#include "src/util/time_now_us.h"
#include "src/xApp/e42_xapp_api.h"

#include <pthread.h>
#include <signal.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

// EMS so the NMS can report which agent version the element runs.
#if defined(E2AP_V1)
#define EMS_E2AP_VERSION "E2AP_V1"
#elif defined(E2AP_V2)
#define EMS_E2AP_VERSION "E2AP_V2"
#elif defined(E2AP_V3)
#define EMS_E2AP_VERSION "E2AP_V3"
#else
#define EMS_E2AP_VERSION "unknown"
#endif

#if defined(KPM_V2_01)
#define EMS_KPM_VERSION "KPM_V2_01"
#elif defined(KPM_V2_03)
#define EMS_KPM_VERSION "KPM_V2_03"
#elif defined(KPM_V3_00)
#define EMS_KPM_VERSION "KPM_V3_00"
#else
#define EMS_KPM_VERSION "unknown"
#endif

// OAI registers the E2SM service models with these RAN function identifiers.
#define SM_KPM_ID 2
#define SM_MAC_ID 142
#define SM_RLC_ID 143
#define SM_PDCP_ID 144
#define SM_GTP_ID 148

#define EMS_MAX_UE 32
#define EMS_MAX_DRB 8
#define EMS_MAX_KPI 32
#define EMS_KPI_NAME_LEN 64
#define EMS_KPI_UNIT_LEN 16
#define EMS_MAX_RAN_FUNCTION 32

#define EMS_DEFAULT_EXPORT_INTERVAL_MS 1000
// Custom E2SM service models accept 1/2/5/10 ms indication periods; 10 ms keeps
// the callback rate low while staying far inside the default export interval.
#define EMS_DEFAULT_IND_INTERVAL "10_ms"
#define EMS_DEFAULT_KPM_PERIOD_MS 1000
// A UE that stops reporting is released after this long so the NMS does not
// keep serving a detached UE.
#define EMS_UE_AGE_US (10 * 1000 * 1000LL)

typedef struct {
  char name[EMS_KPI_NAME_LEN];
  double value;
  char unit[EMS_KPI_UNIT_LEN];
} ems_kpi_t;

typedef struct {
  bool used;
  uint8_t rbid;

  rlc_radio_bearer_stats_t rlc;
  pdcp_radio_bearer_stats_t pdcp;
  bool rlc_valid;
  bool pdcp_valid;

  // Bitrate derivation: the export thread differences the cumulative byte
  // counters the RAN reports, so bitrate is always the derivative of the
  // counter the EMS exposes for the same layer.
  bool prev_valid;
  int64_t prev_us;
  uint32_t prev_rlc_tx_bytes;
  uint32_t prev_rlc_rx_bytes;
  uint32_t prev_pdcp_tx_bytes;
  uint32_t prev_pdcp_rx_bytes;
  double rlc_tx_bitrate;
  double rlc_rx_bitrate;
  double pdcp_tx_bitrate;
  double pdcp_rx_bitrate;
} ems_drb_t;

typedef struct {
  bool used;
  uint32_t rnti;
  int64_t updated_us;

  mac_ue_stats_impl_t mac;
  bool mac_valid;

  bool mac_prev_valid;
  int64_t mac_prev_us;
  uint64_t prev_dl_aggr_bytes;
  uint64_t prev_ul_aggr_bytes;
  double dl_bitrate;
  double ul_bitrate;

  ems_drb_t drb[EMS_MAX_DRB];

  // E2SM-GTP reports the NG-U tunnel per UE and not per bearer, so the tunnel
  // is stored on the UE and attached to every bearer at export time.
  gtp_ngu_t_stats_t gtp;
  bool gtp_valid;

  ems_kpi_t kpi[EMS_MAX_KPI];
  size_t kpi_len;
  int64_t kpi_updated_us;

  // E2SM-KPM identifies a UE by RAN UE ID, which OAI assigns independently of
  // the RNTI; the binding is learned once and reused for the UE's lifetime.
  uint64_t ran_ue_id;
  bool ran_ue_id_valid;
} ems_ue_t;

static struct {
  pthread_mutex_t mtx;
  ems_ue_t ue[EMS_MAX_UE];

  // E2 association state, written by the subscription supervisor only.
  bool e2_connected;
  bool ran_functions_advertised;
  char near_ric_addr[64];
  struct {
    uint16_t id;
    const char *name;
  } ran_function[EMS_MAX_RAN_FUNCTION];
  size_t ran_function_len;
} g_model;

static struct {
  const char *socket_path;
  const char *gnb_id;
  const char *gnb_serial;
  const char *cell_id;
  uint32_t pci;
  int export_interval_ms;
  const char *ind_interval;
  uint32_t kpm_period_ms;
} g_cfg;

static volatile sig_atomic_t g_running = 1;

static void handle_signal(int signo)
{
  (void)signo;
  g_running = 0;
}

static const char *env_string(const char *name, const char *def)
{
  const char *v = getenv(name);
  return (v && v[0]) ? v : def;
}

static long env_long(const char *name, long def)
{
  const char *v = getenv(name);
  if (!v || !v[0])
    return def;
  char *end = NULL;
  long n = strtol(v, &end, 10);
  return (end && *end == '\0') ? n : def;
}

static const char *ran_function_name(uint16_t id)
{
  switch (id) {
  case SM_KPM_ID:  return "KPM";
  case 3:          return "RC";
  case SM_MAC_ID:  return "MAC";
  case SM_RLC_ID:  return "RLC";
  case SM_PDCP_ID: return "PDCP";
  case 145:        return "SLICE";
  case 146:        return "TC";
  case SM_GTP_ID:  return "GTP";
  default:         return "UNKNOWN";
  }
}

// Units of the E2SM-KPM measurements OAI reports for a gNB (3GPP TS 28.552).
static const char *kpm_unit(const char *name)
{
  if (strcmp(name, "DRB.UEThpDl") == 0)
    return "kbps";
  if (strcmp(name, "DRB.UEThpUl") == 0)
    return "kbps";
  if (strcmp(name, "DRB.PdcpSduVolumeDL") == 0)
    return "Mb";
  if (strcmp(name, "DRB.PdcpSduVolumeUL") == 0)
    return "Mb";
  if (strcmp(name, "DRB.RlcSduDelayDl") == 0)
    return "us";
  if (strcmp(name, "RRU.PrbTotDl") == 0)
    return "%";
  if (strcmp(name, "RRU.PrbTotUl") == 0)
    return "%";
  return "";
}

static void copy_kpi(ems_kpi_t *dst, const char *name, double value)
{
  snprintf(dst->name, sizeof(dst->name), "%s", name);
  dst->value = value;
  snprintf(dst->unit, sizeof(dst->unit), "%s", kpm_unit(name));
}

// ---------------------------------------------------------------------------
// Telemetry model
// ---------------------------------------------------------------------------

static ems_ue_t *find_or_create_ue(uint32_t rnti)
{
  ems_ue_t *first_free = NULL;
  for (size_t i = 0; i < EMS_MAX_UE; ++i) {
    ems_ue_t *u = &g_model.ue[i];
    if (u->used && u->rnti == rnti)
      return u;
    if (!u->used && !first_free)
      first_free = u;
  }
  if (first_free) {
    memset(first_free, 0, sizeof(*first_free));
    first_free->used = true;
    first_free->rnti = rnti;
    first_free->updated_us = time_now_us();
  }
  return first_free;
}

static ems_ue_t *find_ue_by_rnti(uint32_t rnti)
{
  for (size_t i = 0; i < EMS_MAX_UE; ++i) {
    ems_ue_t *u = &g_model.ue[i];
    if (u->used && u->rnti == rnti)
      return u;
  }
  return NULL;
}

static ems_drb_t *find_or_create_drb(ems_ue_t *ue, uint8_t rbid)
{
  ems_drb_t *first_free = NULL;
  for (size_t i = 0; i < EMS_MAX_DRB; ++i) {
    ems_drb_t *d = &ue->drb[i];
    if (d->used && d->rbid == rbid)
      return d;
    if (!d->used && !first_free)
      first_free = d;
  }
  if (first_free) {
    memset(first_free, 0, sizeof(*first_free));
    first_free->used = true;
    first_free->rbid = rbid;
  }
  return first_free;
}

// OAI keys E2SM-KPM, E2SM-PDCP and E2SM-GTP reports by RAN UE ID (the rrc_ue_id
// the RRC allocator hands out), while E2SM-MAC and E2SM-RLC are keyed by RNTI,
// and the two identifiers are assigned independently. The PDCP and GTP service
// models carry that RAN UE ID in a member named "rnti", so callers must resolve
// them by RAN UE ID as well. Exact bindings are reused; otherwise the report is
// bound to the first unbound tracked UE, which is deterministic for a
// monolithic gNB.
static ems_ue_t *resolve_ue_by_ran_id(uint64_t ran_ue_id)
{
  ems_ue_t *unbound = NULL;
  size_t used = 0;

  for (size_t i = 0; i < EMS_MAX_UE; ++i) {
    ems_ue_t *u = &g_model.ue[i];
    if (!u->used)
      continue;
    ++used;
    if (u->ran_ue_id_valid && u->ran_ue_id == ran_ue_id)
      return u;
    if (!u->ran_ue_id_valid && !unbound)
      unbound = u;
  }

  if (unbound) {
    unbound->ran_ue_id = ran_ue_id;
    unbound->ran_ue_id_valid = true;
    return unbound;
  }
  (void)used;
  return NULL;
}

// ---------------------------------------------------------------------------
// E2SM indication callbacks
// ---------------------------------------------------------------------------

static void sm_cb_mac(sm_ag_if_rd_t const *rd)
{
  if (rd->type != INDICATION_MSG_AGENT_IF_ANS_V0 || rd->ind.type != MAC_STATS_V0)
    return;

  mac_ind_msg_t const *msg = &rd->ind.mac.msg;
  pthread_mutex_lock(&g_model.mtx);
  for (size_t i = 0; i < msg->len_ue_stats; ++i) {
    ems_ue_t *ue = find_or_create_ue(msg->ue_stats[i].rnti);
    if (!ue)
      break;
    ue->mac = msg->ue_stats[i];
    ue->mac_valid = true;
    ue->updated_us = time_now_us();
  }
  pthread_mutex_unlock(&g_model.mtx);
}

static void sm_cb_rlc(sm_ag_if_rd_t const *rd)
{
  if (rd->type != INDICATION_MSG_AGENT_IF_ANS_V0 || rd->ind.type != RLC_STATS_V0)
    return;

  rlc_ind_msg_t const *msg = &rd->ind.rlc.msg;
  pthread_mutex_lock(&g_model.mtx);
  for (size_t i = 0; i < msg->len; ++i) {
    ems_ue_t *ue = find_or_create_ue(msg->rb[i].rnti);
    if (!ue)
      break;
    ems_drb_t *drb = find_or_create_drb(ue, msg->rb[i].rbid);
    if (!drb)
      break;
    drb->rlc = msg->rb[i];
    drb->rlc_valid = true;
    ue->updated_us = time_now_us();
  }
  pthread_mutex_unlock(&g_model.mtx);
}

static void sm_cb_pdcp(sm_ag_if_rd_t const *rd)
{
  if (rd->type != INDICATION_MSG_AGENT_IF_ANS_V0 || rd->ind.type != PDCP_STATS_V0)
    return;

  pdcp_ind_msg_t const *msg = &rd->ind.pdcp.msg;
  pthread_mutex_lock(&g_model.mtx);
  for (size_t i = 0; i < msg->len; ++i) {
    // E2SM-PDCP identifies the UE by RAN UE ID, carried in the "rnti" member.
    ems_ue_t *ue = resolve_ue_by_ran_id(msg->rb[i].rnti);
    if (!ue)
      break;
    ems_drb_t *drb = find_or_create_drb(ue, msg->rb[i].rbid);
    if (!drb)
      break;
    drb->pdcp = msg->rb[i];
    drb->pdcp_valid = true;
    ue->updated_us = time_now_us();
  }
  pthread_mutex_unlock(&g_model.mtx);
}

static void sm_cb_gtp(sm_ag_if_rd_t const *rd)
{
  if (rd->type != INDICATION_MSG_AGENT_IF_ANS_V0 || rd->ind.type != GTP_STATS_V0)
    return;

  gtp_ind_msg_t const *msg = &rd->ind.gtp.msg;
  pthread_mutex_lock(&g_model.mtx);
  for (size_t i = 0; i < msg->len; ++i) {
    // E2SM-GTP identifies the UE by RAN UE ID, carried in the "rnti" member.
    ems_ue_t *ue = resolve_ue_by_ran_id(msg->ngut[i].rnti);
    if (!ue)
      break;
    ue->gtp = msg->ngut[i];
    ue->gtp_valid = true;
    ue->updated_us = time_now_us();
  }
  pthread_mutex_unlock(&g_model.mtx);
}

static void store_kpm_measurements(ems_ue_t *ue, kpm_ind_msg_format_1_t const *frm_1)
{
  for (size_t j = 0; j < frm_1->meas_data_lst_len && j < 1; ++j) {
    meas_data_lst_t const *data = &frm_1->meas_data_lst[j];
    for (size_t i = 0; i < frm_1->meas_info_lst_len; ++i) {
      if (i >= data->meas_record_len)
        break;
      meas_info_format_1_lst_t const *info = &frm_1->meas_info_lst[i];
      if (info->meas_type.type != NAME_MEAS_TYPE)
        continue;

      meas_record_lst_t const *rec = &data->meas_record_lst[i];
      double value = 0.0;
      if (rec->value == INTEGER_MEAS_VALUE)
        value = (double)rec->int_val;
      else if (rec->value == REAL_MEAS_VALUE)
        value = rec->real_val;
      else
        continue;

      char *name = cp_ba_to_str(info->meas_type.name);
      if (!name)
        continue;
      if (ue->kpi_len < EMS_MAX_KPI)
        copy_kpi(&ue->kpi[ue->kpi_len++], name, value);
      else
        fprintf(stderr, "ems-metrics: kpi list full, dropping %s\n", name);
      free(name);
    }
  }
  ue->kpi_updated_us = time_now_us();
}

static void sm_cb_kpm(sm_ag_if_rd_t const *rd)
{
  if (rd->type != INDICATION_MSG_AGENT_IF_ANS_V0 || rd->ind.type != KPM_STATS_V3_0)
    return;

  kpm_ind_data_t const *ind = &rd->ind.kpm.ind;
  if (ind->msg.type != FORMAT_3_INDICATION_MESSAGE)
    return;

  kpm_ind_msg_format_3_t const *frm_3 = &ind->msg.frm_3;
  pthread_mutex_lock(&g_model.mtx);
  for (size_t i = 0; i < frm_3->ue_meas_report_lst_len; ++i) {
    meas_report_per_ue_t const *per_ue = &frm_3->meas_report_per_ue[i];
    ue_id_e2sm_t const *ue_id = &per_ue->ue_meas_report_lst;
    if (ue_id->type != GNB_UE_ID_E2SM || !ue_id->gnb.ran_ue_id)
      continue;

    ems_ue_t *ue = resolve_ue_by_ran_id(*ue_id->gnb.ran_ue_id);
    if (!ue)
      continue;
    ue->kpi_len = 0;
    store_kpm_measurements(ue, &per_ue->ind_msg_format_1);
    ue->updated_us = time_now_us();
  }
  pthread_mutex_unlock(&g_model.mtx);
}

// ---------------------------------------------------------------------------
// E2SM-KPM subscription (adapted from examples/xApp/c/monitor/xapp_kpm_moni.c)
// ---------------------------------------------------------------------------

static label_info_lst_t fill_kpm_label(void)
{
  label_info_lst_t label = {0};
  label.noLabel = calloc(1, sizeof(enum_value_e));
  if (label.noLabel)
    *label.noLabel = TRUE_ENUM_VALUE;
  return label;
}

static test_info_lst_t kpm_match_snssai(int value)
{
  test_info_lst_t dst = {0};
  dst.test_cond_type = S_NSSAI_TEST_COND_TYPE;
  dst.S_NSSAI = TRUE_TEST_COND_TYPE;

  dst.test_cond = calloc(1, sizeof(test_cond_e));
  dst.test_cond_value = calloc(1, sizeof(test_cond_value_t));
  dst.test_cond_value->octet_string_value = calloc(1, sizeof(byte_array_t));
  if (!dst.test_cond || !dst.test_cond_value || !dst.test_cond_value->octet_string_value)
    return dst;

  *dst.test_cond = EQUAL_TEST_COND;
  dst.test_cond_value->type = OCTET_STRING_TEST_COND_VALUE;
  dst.test_cond_value->octet_string_value->len = 1;
  dst.test_cond_value->octet_string_value->buf = calloc(1, 1);
  if (dst.test_cond_value->octet_string_value->buf)
    dst.test_cond_value->octet_string_value->buf[0] = (uint8_t)value;
  return dst;
}

static kpm_act_def_format_1_t kpm_act_def_format_1(ric_report_style_item_t const *item)
{
  kpm_act_def_format_1_t ad = {0};
  ad.meas_info_lst_len = item->meas_info_for_action_lst_len;
  ad.meas_info_lst = calloc(ad.meas_info_lst_len, sizeof(meas_info_format_1_lst_t));
  if (!ad.meas_info_lst) {
    ad.meas_info_lst_len = 0;
    return ad;
  }
  for (size_t i = 0; i < ad.meas_info_lst_len; ++i) {
    meas_info_format_1_lst_t *mi = &ad.meas_info_lst[i];
    mi->meas_type.type = NAME_MEAS_TYPE;
    mi->meas_type.name = copy_byte_array(item->meas_info_for_action_lst[i].name);
    mi->label_info_lst_len = 1;
    mi->label_info_lst = calloc(1, sizeof(label_info_lst_t));
    if (mi->label_info_lst)
      mi->label_info_lst[0] = fill_kpm_label();
  }
  ad.gran_period_ms = g_cfg.kpm_period_ms;
  ad.cell_global_id = NULL;
#if defined(KPM_V2_03) || defined(KPM_V3_00)
  ad.meas_bin_range_info_lst_len = 0;
  ad.meas_bin_info_lst = NULL;
#endif
  return ad;
}

static bool subscribe_kpm(e2_node_connected_xapp_t *n)
{
  size_t idx = n->len_rf;
  for (size_t i = 0; i < n->len_rf; ++i) {
    if (n->rf[i].id == SM_KPM_ID) {
      idx = i;
      break;
    }
  }
  if (idx >= n->len_rf || n->rf[idx].defn.type != KPM_RAN_FUNC_DEF_E)
    return false;

  kpm_ran_function_def_t const *def = &n->rf[idx].defn.kpm;
  if (def->sz_ric_event_trigger_style_list == 0 || !def->ric_event_trigger_style_list)
    return false;
  if (def->ric_event_trigger_style_list[0].format_type != FORMAT_1_RIC_EVENT_TRIGGER)
    return false;

  ric_report_style_item_t *style = NULL;
  for (size_t j = 0; j < def->sz_ric_report_style_list; ++j) {
    ric_report_style_item_t *it = &def->ric_report_style_list[j];
    if (it->report_style_type == STYLE_4_RIC_SERVICE_REPORT &&
        it->act_def_format_type == FORMAT_4_ACTION_DEFINITION) {
      style = it;
      break;
    }
  }
  if (!style)
    return false;

  kpm_sub_data_t sub = {0};
  sub.ev_trg_def.type = FORMAT_1_RIC_EVENT_TRIGGER;
  sub.ev_trg_def.kpm_ric_event_trigger_format_1.report_period_ms = g_cfg.kpm_period_ms;
  sub.sz_ad = 1;
  sub.ad = calloc(1, sizeof(kpm_act_def_t));
  if (!sub.ad)
    return false;

  sub.ad->type = FORMAT_4_ACTION_DEFINITION;
  kpm_act_def_format_4_t *frm4 = &sub.ad->frm_4;
  frm4->matching_cond_lst_len = 1;
  frm4->matching_cond_lst = calloc(1, sizeof(matching_condition_format_4_lst_t));
  if (!frm4->matching_cond_lst) {
    free_kpm_sub_data(&sub);
    return false;
  }
  frm4->matching_cond_lst[0].test_info_lst = kpm_match_snssai(1);
  frm4->action_def_format_1 = kpm_act_def_format_1(style);

  sm_ans_xapp_t ans = report_sm_xapp_api(&n->id, SM_KPM_ID, &sub, sm_cb_kpm);
  free_kpm_sub_data(&sub);
  return ans.success;
}

static void record_ran_functions(e2_node_connected_xapp_t const *n)
{
  g_model.ran_function_len = 0;
  for (size_t j = 0; j < n->len_rf && g_model.ran_function_len < EMS_MAX_RAN_FUNCTION; ++j) {
    g_model.ran_function[g_model.ran_function_len].id = n->rf[j].id;
    g_model.ran_function[g_model.ran_function_len].name = ran_function_name(n->rf[j].id);
    ++g_model.ran_function_len;
  }
  g_model.ran_functions_advertised = g_model.ran_function_len > 0;
}

static bool subscribe_node(e2_node_connected_xapp_t *n)
{
  if (n->id.type != ngran_gNB) {
    fprintf(stderr, "ems-metrics: skipping non-monolithic node type %d\n", (int)n->id.type);
    return false;
  }

  sm_ans_xapp_t mac = report_sm_xapp_api(&n->id, SM_MAC_ID, (void *)g_cfg.ind_interval, sm_cb_mac);
  sm_ans_xapp_t rlc = report_sm_xapp_api(&n->id, SM_RLC_ID, (void *)g_cfg.ind_interval, sm_cb_rlc);
  sm_ans_xapp_t pdcp = report_sm_xapp_api(&n->id, SM_PDCP_ID, (void *)g_cfg.ind_interval, sm_cb_pdcp);
  sm_ans_xapp_t gtp = report_sm_xapp_api(&n->id, SM_GTP_ID, (void *)g_cfg.ind_interval, sm_cb_gtp);

  if (!mac.success || !rlc.success || !pdcp.success || !gtp.success) {
    fprintf(stderr, "ems-metrics: subscription failed: mac=%d rlc=%d pdcp=%d gtp=%d\n",
            mac.success, rlc.success, pdcp.success, gtp.success);
    return false;
  }

  // KPM is optional: a node without a usable REPORT style 4 still exports the
  // full E2SM-MAC/RLC/PDCP/GTP telemetry.
  bool const kpm_ok = subscribe_kpm(n);
  if (!kpm_ok)
    fprintf(stderr, "ems-metrics: KPM subscription unavailable, continuing without KPM\n");

  pthread_mutex_lock(&g_model.mtx);
  record_ran_functions(n);
  g_model.e2_connected = true;
  pthread_mutex_unlock(&g_model.mtx);

  printf("ems-metrics: subscribed to E2 node (ran functions: %zu, kpm: %s)\n",
         g_model.ran_function_len, kpm_ok ? "on" : "off");
  return true;
}

// ---------------------------------------------------------------------------
// Serialization
// ---------------------------------------------------------------------------

static void write_harq(ems_json_writer_t *w, const char *key, const uint32_t *harq)
{
  ems_json_printf(w, "%Q: [%d, %d, %d, %d, %d]",
                  key, harq[0], harq[1], harq[2], harq[3], harq[4]);
}

static double bitrate_per_second(uint64_t cur, uint64_t prev, double dt_s)
{
  if (dt_s <= 0.0)
    return 0.0;
  uint64_t delta = (cur >= prev) ? (cur - prev) : 0;
  return ((double)delta * 8.0) / dt_s;
}

static double bitrate_u32(uint32_t cur, uint32_t prev, double dt_s)
{
  if (dt_s <= 0.0)
    return 0.0;
  // The RAN reports 32-bit counters, so a wrap around is treated as no data.
  uint32_t delta = (cur >= prev) ? (uint32_t)(cur - prev) : 0;
  return ((double)delta * 8.0) / dt_s;
}

// Sanitizes a measurement into a finite value: JSON has no representation for
// NaN or infinity, and a non-finite leaf would make the whole envelope
// unparseable for the EMS agent.
static double finite_or_zero(double v)
{
  return (v == v && v < 1.0e18 && v > -1.0e18) ? v : 0.0;
}

static void write_rlc_container(ems_json_writer_t *w, ems_drb_t *d, double dt_s)
{
  rlc_radio_bearer_stats_t const *s = &d->rlc;
  d->rlc_tx_bitrate = bitrate_u32(s->txpdu_bytes, d->prev_rlc_tx_bytes, dt_s);
  d->rlc_rx_bitrate = bitrate_u32(s->rxpdu_bytes, d->prev_rlc_rx_bytes, dt_s);
  d->prev_rlc_tx_bytes = s->txpdu_bytes;
  d->prev_rlc_rx_bytes = s->rxpdu_bytes;

  // One format string per container keeps the field list and the separators
  // in one place: Frozen emits the commas from the literal text, so no call
  // site can ever place (or forget) one by hand.
  ems_json_printf(w,
      "rlc_container: {"
      "txpdu_pkts: %d, txpdu_bytes: %llu, txpdu_wt_ms: %d, "
      "txpdu_dd_pkts: %d, txpdu_dd_bytes: %d, "
      "txpdu_retx_pkts: %d, txpdu_retx_bytes: %d, "
      "txpdu_segmented: %d, "
      "txpdu_status_pkts: %d, txpdu_status_bytes: %d, "
      "txbuf_occ_bytes: %d, txbuf_occ_pkts: %d, "
      "rxpdu_pkts: %d, rxpdu_bytes: %llu, "
      "rxpdu_dup_pkts: %d, rxpdu_dup_bytes: %d, "
      "rxpdu_dd_pkts: %d, rxpdu_dd_bytes: %d, "
      "rxpdu_ow_pkts: %d, rxpdu_ow_bytes: %d, "
      "rxpdu_status_pkts: %d, rxpdu_status_bytes: %d, "
      "rxbuf_occ_bytes: %d, rxbuf_occ_pkts: %d, "
      "txsdu_pkts: %d, txsdu_bytes: %llu, "
      "txsdu_avg_time_to_tx: %.6f, txsdu_wt_us: %d, "
      "rxsdu_pkts: %d, rxsdu_bytes: %llu, "
      "rxsdu_dd_pkts: %d, rxsdu_dd_bytes: %d, "
      "mode: %d, "
      "tx_bitrate: %.6f, rx_bitrate: %.6f"
      "}",
      s->txpdu_pkts, (unsigned long long)s->txpdu_bytes, s->txpdu_wt_ms,
      s->txpdu_dd_pkts, s->txpdu_dd_bytes,
      s->txpdu_retx_pkts, s->txpdu_retx_bytes,
      s->txpdu_segmented,
      s->txpdu_status_pkts, s->txpdu_status_bytes,
      s->txbuf_occ_bytes, s->txbuf_occ_pkts,
      s->rxpdu_pkts, (unsigned long long)s->rxpdu_bytes,
      s->rxpdu_dup_pkts, s->rxpdu_dup_bytes,
      s->rxpdu_dd_pkts, s->rxpdu_dd_bytes,
      s->rxpdu_ow_pkts, s->rxpdu_ow_bytes,
      s->rxpdu_status_pkts, s->rxpdu_status_bytes,
      s->rxbuf_occ_bytes, s->rxbuf_occ_pkts,
      s->txsdu_pkts, (unsigned long long)s->txsdu_bytes,
      finite_or_zero(s->txsdu_avg_time_to_tx), s->txsdu_wt_us,
      s->rxsdu_pkts, (unsigned long long)s->rxsdu_bytes,
      s->rxsdu_dd_pkts, s->rxsdu_dd_bytes,
      s->mode,
      finite_or_zero(d->rlc_tx_bitrate), finite_or_zero(d->rlc_rx_bitrate));
}

static void write_pdcp_container(ems_json_writer_t *w, ems_drb_t *d, double dt_s)
{
  pdcp_radio_bearer_stats_t const *s = &d->pdcp;
  d->pdcp_tx_bitrate = bitrate_u32(s->txpdu_bytes, d->prev_pdcp_tx_bytes, dt_s);
  d->pdcp_rx_bitrate = bitrate_u32(s->rxpdu_bytes, d->prev_pdcp_rx_bytes, dt_s);
  d->prev_pdcp_tx_bytes = s->txpdu_bytes;
  d->prev_pdcp_rx_bytes = s->rxpdu_bytes;

  ems_json_printf(w,
      "pdcp_container: {"
      "txpdu_pkts: %d, txpdu_bytes: %llu, txpdu_sn: %d, "
      "rxpdu_pkts: %d, rxpdu_bytes: %llu, rxpdu_sn: %d, "
      "rxpdu_oo_pkts: %d, rxpdu_oo_bytes: %d, "
      "rxpdu_dd_pkts: %d, rxpdu_dd_bytes: %d, "
      "rxpdu_ro_count: %d, "
      "txsdu_pkts: %d, txsdu_bytes: %llu, "
      "rxsdu_pkts: %d, rxsdu_bytes: %llu, "
      "mode: %d, "
      "tx_bitrate: %.6f, rx_bitrate: %.6f"
      "}",
      s->txpdu_pkts, (unsigned long long)s->txpdu_bytes, s->txpdu_sn,
      s->rxpdu_pkts, (unsigned long long)s->rxpdu_bytes, s->rxpdu_sn,
      s->rxpdu_oo_pkts, s->rxpdu_oo_bytes,
      s->rxpdu_dd_pkts, s->rxpdu_dd_bytes,
      s->rxpdu_ro_count,
      s->txsdu_pkts, (unsigned long long)s->txsdu_bytes,
      s->rxsdu_pkts, (unsigned long long)s->rxsdu_bytes,
      s->mode,
      finite_or_zero(d->pdcp_tx_bitrate), finite_or_zero(d->pdcp_rx_bitrate));
}

static void write_drb_list(ems_json_writer_t *w, ems_ue_t *ue, double dt_s)
{
  ems_json_printf(w, "drb_list: [");
  bool first = true;
  for (size_t i = 0; i < EMS_MAX_DRB; ++i) {
    ems_drb_t *d = &ue->drb[i];
    if (!d->used || (!d->rlc_valid && !d->pdcp_valid))
      continue;

    // One bearer is one object; the separator is part of the format literal.
    if (!first)
      ems_json_printf(w, ", ");
    first = false;

    ems_json_printf(w, "{drb_id: %d", d->rbid);
    if (d->rlc_valid) {
      ems_json_printf(w, ", ");
      write_rlc_container(w, d, dt_s);
    }
    if (d->pdcp_valid) {
      ems_json_printf(w, ", ");
      write_pdcp_container(w, d, dt_s);
    }
    if (ue->gtp_valid) {
      ems_json_printf(w,
          ", gtp_container: {teidgnb: %d, teidupf: %d, qfi: %d}",
          ue->gtp.teidgnb, ue->gtp.teidupf, ue->gtp.qfi);
    }
    ems_json_printf(w, "}");
  }
  ems_json_printf(w, "]");
}

static void write_kpi_list(ems_json_writer_t *w, ems_ue_t const *ue)
{
  ems_json_printf(w, "kpi_list: [");
  for (size_t i = 0; i < ue->kpi_len; ++i) {
    ems_json_printf(w, "%s{name: %Q, value: %.6f, unit: %Q}",
                    i ? ", " : "",
                    ue->kpi[i].name, finite_or_zero(ue->kpi[i].value),
                    ue->kpi[i].unit);
  }
  ems_json_printf(w, "]");
}

static void write_ue(ems_json_writer_t *w, ems_ue_t *ue, double dt_s)
{
  // ran_ue_id is a string: OAI assigns it as a 64-bit value but the EMS models
  // it as an opaque identifier, so the envelope keeps the text form.
  char ran_ue_id[32];
  if (ue->ran_ue_id_valid)
    snprintf(ran_ue_id, sizeof(ran_ue_id), "%llu", (unsigned long long)ue->ran_ue_id);
  else
    ran_ue_id[0] = '\0';

  ems_json_printf(w, "{ue_rnti: %d, ran_ue_id: %Q", ue->rnti, ran_ue_id);

  if (ue->mac_valid) {
    mac_ue_stats_impl_t const *m = &ue->mac;
    // dl_aggr_tbs/ul_aggr_tbs are the cumulative scheduled bytes; unlike
    // lc_bytes[3] (exported as dl_aggr_bytes_sdus) they always advance while
    // data flows, so they are the reliable source for a bitrate derivative.
    ue->dl_bitrate = bitrate_per_second(m->dl_aggr_tbs, ue->prev_dl_aggr_bytes, dt_s);
    ue->ul_bitrate = bitrate_per_second(m->ul_aggr_tbs, ue->prev_ul_aggr_bytes, dt_s);
    ue->prev_dl_aggr_bytes = m->dl_aggr_tbs;
    ue->prev_ul_aggr_bytes = m->ul_aggr_tbs;

    ems_json_printf(w,
        ", mac_container: {"
        "dl_bitrate: %.6f, ul_bitrate: %.6f, "
        "dl_bler: %.6f, ul_bler: %.6f, "
        "pusch_snr: %.6f, pucch_snr: %.6f, "
        "dl_mcs: %d, ul_mcs: %d, dl_mcs2: %d, ul_mcs2: %d, "
        "wb_cqi: %d, ul_phr: %d, ul_bsr: %d, "
        "dl_sched_rb: %d, ul_sched_rb: %d, "
        "dl_aggr_prb: %d, ul_aggr_prb: %d, "
        "dl_aggr_retx_prb: %d, ul_aggr_retx_prb: %d, "
        "dl_aggr_sdus: %d, ul_aggr_sdus: %d, "
        "dl_aggr_bytes: %llu, ul_aggr_bytes: %llu, "
        "dl_aggr_tbs: %llu, ul_aggr_tbs: %llu, "
        "dl_curr_tbs: %llu, ul_curr_tbs: %llu, "
        "frame: %d, slot: %d, "
        "dl_num_harq: %d, ul_num_harq: %d, ",
        finite_or_zero(ue->dl_bitrate), finite_or_zero(ue->ul_bitrate),
        finite_or_zero((double)m->dl_bler), finite_or_zero((double)m->ul_bler),
        finite_or_zero((double)m->pusch_snr), finite_or_zero((double)m->pucch_snr),
        m->dl_mcs1, m->ul_mcs1, m->dl_mcs2, m->ul_mcs2,
        m->wb_cqi, (int)m->phr, m->bsr,
        (int)m->dl_sched_rb, (int)m->ul_sched_rb,
        m->dl_aggr_prb, m->ul_aggr_prb,
        m->dl_aggr_retx_prb, m->ul_aggr_retx_prb,
        m->dl_aggr_sdus, m->ul_aggr_sdus,
        (unsigned long long)m->dl_aggr_bytes_sdus,
        (unsigned long long)m->ul_aggr_bytes_sdus,
        (unsigned long long)m->dl_aggr_tbs, (unsigned long long)m->ul_aggr_tbs,
        (unsigned long long)m->dl_curr_tbs, (unsigned long long)m->ul_curr_tbs,
        m->frame, m->slot,
        m->dl_num_harq, m->ul_num_harq);
    write_harq(w, "dl_harq", m->dl_harq);
    ems_json_printf(w, ", ");
    write_harq(w, "ul_harq", m->ul_harq);
    ems_json_printf(w, "}");
  }

  ems_json_printf(w, ", ");
  write_drb_list(w, ue, dt_s);
  ems_json_printf(w, ", ");
  write_kpi_list(w, ue);
  ems_json_printf(w, "}");
}

static void age_model(int64_t now_us)
{
  for (size_t i = 0; i < EMS_MAX_UE; ++i) {
    ems_ue_t *ue = &g_model.ue[i];
    if (!ue->used)
      continue;
    if (now_us - ue->updated_us > EMS_UE_AGE_US)
      memset(ue, 0, sizeof(*ue));
  }
}

// The xApp has no direct NGAP visibility: it reports the E2 management-plane
// association, which is the authoritative transport for this element. NGAP
// readiness is only advertised once the gNB completed a full E2 setup (RAN
// function advertisement), so an element that is reachable but not yet fully
// registered is still distinguishable from a down element.
static void node_status(bool *e2_ok, bool *ngap_ok)
{
  *e2_ok = g_model.e2_connected;
  *ngap_ok = g_model.e2_connected && g_model.ran_functions_advertised;
}

static void *export_loop(void *arg)
{
  (void)arg;
  ems_json_writer_t w;
  ems_json_init(&w);

  int const interval_us = g_cfg.export_interval_ms * 1000;
  int64_t prev_export_us = 0;

  while (g_running) {
    usleep(interval_us);
    int64_t now_us = time_now_us();
    double dt_s = prev_export_us ? (double)(now_us - prev_export_us) / 1.0e6 : 0.0;
    prev_export_us = now_us;

    pthread_mutex_lock(&g_model.mtx);
    age_model(now_us);

    bool e2_ok, ngap_ok;
    node_status(&e2_ok, &ngap_ok);

    ems_json_clear(&w);

    ems_json_printf(&w, "{type: %Q, timestamp: %.6f, gnb_id: %Q, gnb_serial: %Q",
                    "gnb_metrics", (double)now_us / 1.0e6, g_cfg.gnb_id,
                    g_cfg.gnb_serial);

    ems_json_printf(&w,
        ", e2_container: {e2_status: %Q, e2_status_code: %d, "
        "near_ric_addr: %Q, e2ap_version: %Q, kpm_version: %Q, ran_function_list: [",
        e2_ok ? "connected" : "not_ready", e2_ok ? 1 : 0,
        g_model.near_ric_addr, EMS_E2AP_VERSION, EMS_KPM_VERSION);
    for (size_t i = 0; i < g_model.ran_function_len; ++i)
      ems_json_printf(&w, "%s{id: %d, name: %Q}", i ? ", " : "",
                      g_model.ran_function[i].id, g_model.ran_function[i].name);
    ems_json_printf(&w, "]}");

    ems_json_printf(&w,
        ", ngap_container: {ngap_status: %Q, ngap_status_code: %d}",
        ngap_ok ? "connected" : "not_ready", ngap_ok ? 1 : 0);

    uint32_t total_ues = 0;
    uint32_t connected_ues = 0;
    for (size_t i = 0; i < EMS_MAX_UE; ++i) {
      if (!g_model.ue[i].used)
        continue;
      ++total_ues;
      if (g_model.ue[i].mac_valid)
        ++connected_ues;
    }
    ems_json_printf(&w,
        ", rrc_container: {rrc_total_ues: %d, rrc_connected_ues: %d}",
        total_ues, connected_ues);

    ems_json_printf(&w,
        ", cell_list: [{nr_cell_id: %Q, nci: %Q, pci: %d, ue_list: [",
        g_cfg.cell_id, g_cfg.cell_id, g_cfg.pci);
    bool first = true;
    for (size_t i = 0; i < EMS_MAX_UE; ++i) {
      ems_ue_t *ue = &g_model.ue[i];
      if (!ue->used)
        continue;
      if (!first)
        ems_json_printf(&w, ", ");
      first = false;
      write_ue(&w, ue, dt_s);
    }
    ems_json_printf(&w, "]}]}");

    pthread_mutex_unlock(&g_model.mtx);

    if (ems_json_send_uds(&w, g_cfg.socket_path) != 0)
      fprintf(stderr, "ems-metrics: failed to export telemetry to %s\n", g_cfg.socket_path);
  }

  ems_json_free(&w);
  return NULL;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

int main(int argc, char *argv[])
{
  g_cfg.socket_path = env_string("EMS_GNB_METRICS_SOCKET", "/var/run/gnb-metrics/gnb_metrics.uds");
  g_cfg.gnb_id = env_string("GNB_ID", "gnb-rfsim");
  g_cfg.gnb_serial = env_string("GNB_SERIAL", "oai-gnb-1");
  g_cfg.cell_id = env_string("GNB_NR_CELL_ID", "12345678");
  g_cfg.pci = (uint32_t)env_long("GNB_PCI", 0);
  g_cfg.export_interval_ms = (int)env_long("XAPP_EXPORT_INTERVAL_MS", EMS_DEFAULT_EXPORT_INTERVAL_MS);
  g_cfg.ind_interval = env_string("XAPP_IND_INTERVAL", EMS_DEFAULT_IND_INTERVAL);
  g_cfg.kpm_period_ms = (uint32_t)env_long("KPM_PERIOD_MS", EMS_DEFAULT_KPM_PERIOD_MS);
  if (g_cfg.export_interval_ms < 100)
    g_cfg.export_interval_ms = 100;

  fr_args_t args = init_fr_args(argc, argv);
  snprintf(g_model.near_ric_addr, sizeof(g_model.near_ric_addr), "%s", get_near_ric_ip(&args));

  pthread_mutex_init(&g_model.mtx, NULL);
  init_xapp_api(&args);

  struct sigaction sa;
  memset(&sa, 0, sizeof(sa));
  sa.sa_handler = handle_signal;
  sigaction(SIGTERM, &sa, NULL);
  sigaction(SIGINT, &sa, NULL);

  pthread_t exporter;
  pthread_create(&exporter, NULL, export_loop, NULL);

  // The gNB may start after the xApp, and the E2 association may be re-created
  // at runtime, so subscriptions are (re)established whenever an E2 node is
  // present and none is active.
  bool subscribed = false;
  while (g_running) {
    e2_node_arr_xapp_t nodes = e2_nodes_xapp_api();
    if (nodes.len > 0) {
      if (!subscribed) {
        for (size_t i = 0; i < nodes.len && !subscribed; ++i)
          subscribed = subscribe_node(&nodes.n[i]);
      }
    } else if (subscribed) {
      pthread_mutex_lock(&g_model.mtx);
      g_model.e2_connected = false;
      g_model.ran_functions_advertised = false;
      pthread_mutex_unlock(&g_model.mtx);
      subscribed = false;
      fprintf(stderr, "ems-metrics: E2 node disconnected, will resubscribe\n");
    }
    free_e2_node_arr_xapp(&nodes);
    sleep(2);
  }

  pthread_join(exporter, NULL);
  while (try_stop_xapp_api() == false)
    usleep(1000);
  pthread_mutex_destroy(&g_model.mtx);
  return 0;
}
