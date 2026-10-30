-include .env
export

.PHONY: help submodules lte-element-manager-clone netconf-client build build-fast build-4g build-4g-fast build-5g build-5g-fast build-oai5g build-open5gs5g build-ems-gnb build-ems-o5gc pull-images pull-images-5g up up-4g up-5g down down-4g down-5g restart restart-4g restart-5g build-ems build-enb build-ems-fast build-enb-fast ue1-shell ue2-shell enb1-shell enb2-shell epc-shell ems1-shell ems2-shell logs logs-all logs-epc logs-enb1 logs-enb2 logs-ue1 logs-ue2 logs-ems1 logs-ems2 logs-ems-epc logs-radio-supervisor logs-5g logs-5g-core logs-5g-gnb logs-5g-ue logs-5g-ems-gnb logs-5g-ems-o5gc net-check net-check-5g netconf-keys netconf-poll-gnb netconf-poll-gnb-e2 netconf-poll-gnb-ues netconf-poll-gnb-kpis netconf-poll-open5gs netconf-poll-open5gs-amf netconf-poll-open5gs-smf netconf-poll-open5gs-upf netconf-poll-open5gs-pcf netconf-poll-open5gs-metrics netconf-poll-open5gs-amf-metrics netconf-poll-open5gs-smf-metrics netconf-poll-open5gs-upf-metrics netconf-poll-open5gs-pcf-metrics netconf-poll-open5gs-amf-performance netconf-poll-open5gs-smf-performance netconf-poll-open5gs-upf-performance netconf-poll-open5gs-pcf-performance netconf-poll-open5gs-amf-info netconf-poll-open5gs-smf-info netconf-poll-open5gs-amf-dump netconf-poll-open5gs-smf-dump netconf-poll-open5gs-alarms netconf-poll-open5gs-amf-alarms netconf-poll-open5gs-smf-alarms netconf-poll-open5gs-upf-alarms netconf-poll-open5gs-pcf-alarms o5gs-inject-alarm o5gs-inject-reset o5gs-synthetic o5gs-synthetic-clear o5gs-synthetic-all o5gs-synthetic-clear-all netconf-poll-enb1 netconf-poll-enb2 netconf-poll-enb1-nrm netconf-poll-enb2-nrm netconf-poll-enb1-nrm-cells netconf-poll-enb2-nrm-cells netconf-hold-lock-enb1 netconf-hold-lock-enb2 nbi-edit-enb1-nprb nbi-edit-enb2-nprb tca-inject-enb1 tca-inject-enb2 o5gs-alarm-nf-down o5gs-alarm-nf-up o5gs-alarm-all-down o5gs-alarm-all-up o5gs-alarm-gnb-down o5gs-alarm-gnb-up o5gs-alarm-status o5gs-alarm-demo restart-enb-by-serial restart-radio-pair1 restart-radio-pair2 iperf-epc-server iperf-ue1-server iperf-ue2-server iperf-ue1-dl iperf-ue1-ul iperf-ue2-dl iperf-ue2-ul iperf-5g-dl iperf-5g-ul clean clean-5g distclean

help:
	@echo "4G (default): make build && make up"
	@echo "5G RFSimulator: make build-5g && make up-5g && make net-check-5g"
	@echo "5G metrics:     make netconf-poll-gnb (or -e2 / -ues / -kpis)"
	@echo "5GC metrics:     make netconf-poll-open5gs (or -amf / -smf / -upf / -pcf / -metrics / -info / -dump)
	@echo "Useful 5G targets: logs-5g, logs-5g-core, logs-5g-gnb, logs-5g-ems-gnb, logs-5g-ue, iperf-5g-dl, iperf-5g-ul, down-5g"

POLL_INTERVAL ?= 1
SERIAL ?=
NPRB ?= 50
DOWN_TIMEOUT ?= 10
IPERF_DURATION ?= 10
LOCK_SECONDS ?= 60
TCA_MOI_ENB1 ?= SubNetwork=srsRAN/ManagedElement=enb1/ENBFunction=1
TCA_MOI_ENB2 ?= SubNetwork=srsRAN/ManagedElement=enb2/ENBFunction=1
TCA_METRIC ?= s1ap.ready
TCA_VALUE ?= 0
TCA_REPEAT ?= 1
TCA_DELAY ?= 1

lte-element-manager-clone: submodules
	$(MAKE) -C externals/lte-element-manager clone

netconf-client: lte-element-manager-clone
	$(MAKE) -C externals/lte-element-manager netconf-client

build: build-4g

build-fast: build-4g-fast

build-4g: submodules lte-element-manager-clone pull-images
	DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker compose build

build-4g-fast: submodules lte-element-manager-clone
	DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker compose build

build-5g: submodules pull-images-5g build-oai5g build-ems-gnb build-ems-o5gc build-open5gs5g

build-5g-fast: submodules
	DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker compose -f docker-compose.5g.yml build open5gs-5gc

build-open5gs5g: submodules
	DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker compose -f docker-compose.5g.yml build open5gs-5gc

build-oai5g: submodules
	DOCKER_BUILDKIT=1 docker build -t ran-base:latest -t srsran4g-nms-oai-ran-base:local -f build/oai5g/Dockerfile.base.rfsim.ubuntu externals/openairinterface5g
	DOCKER_BUILDKIT=1 docker build -t ran-build:latest -t srsran4g-nms-oai-ran-build:local -f build/oai5g/Dockerfile.build.rfsim.ubuntu externals/openairinterface5g
	DOCKER_BUILDKIT=1 docker build -t srsran4g-nms-oai-gnb:local -f build/oai5g/Dockerfile.gNB.rfsim.ubuntu .
	DOCKER_BUILDKIT=1 docker build -t srsran4g-nms-oai-nr-ue:local -f build/oai5g/Dockerfile.nrUE.rfsim.ubuntu externals/openairinterface5g

build-ems-gnb: submodules
	DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker compose -f docker-compose.5g.yml build ems-gnb

build-ems-o5gc: submodules
	DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker compose -f docker-compose.5g.yml build ems-o5gc

build-ems: submodules lte-element-manager-clone pull-images
	DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker compose build ems-enb1 ems-enb2

build-enb: submodules pull-images
	DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker compose build srsenb-1 srsenb-2

build-ems-fast: submodules lte-element-manager-clone
	DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker compose build ems-enb1 ems-enb2

build-enb-fast: submodules
	DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker compose build srsenb-1 srsenb-2

pull-images:
	bash build/scripts/pull_base_images.sh

pull-images-5g:
	docker compose -f docker-compose.5g.yml pull mongo-5g

submodules:
	git submodule sync --recursive
	git submodule update --init --recursive --depth 1

up: up-4g

up-4g: submodules
	docker compose up -d

up-5g: submodules
	docker compose -f docker-compose.5g.yml up -d

down: down-4g

down-4g:
	docker compose down -t $(DOWN_TIMEOUT)

down-5g:
	docker compose -f docker-compose.5g.yml down -t $(DOWN_TIMEOUT) --remove-orphans

restart: restart-4g

restart-4g: down-4g up-4g

restart-5g: down-5g up-5g

ue1-shell:
	docker exec -it UE-1 bash

ue2-shell:
	docker exec -it UE-2 bash

enb1-shell:
	docker exec -it ENB-1 bash

enb2-shell:
	docker exec -it ENB-2 bash

epc-shell:
	docker exec -it EPC bash

ems1-shell:
	docker exec -it EMS-ENB-1 sh

ems2-shell:
	docker exec -it EMS-ENB-2 sh

ems-epc-shell:
	docker exec -it EMS-EPC sh

logs-epc-metrics:
	docker compose logs -f srsepc

logs:
	docker compose logs -f

logs-all:
	docker compose logs -f

logs-epc:
	docker compose logs -f srsepc

logs-enb1:
	docker compose logs -f srsenb-1

logs-enb2:
	docker compose logs -f srsenb-2

logs-ue1:
	docker compose logs -f srsue

logs-ue2:
	docker compose logs -f srsue-2

logs-ems1:
	docker compose logs -f ems-enb1

logs-ems2:
	docker compose logs -f ems-enb2

logs-ems-epc:
	docker compose logs -f ems-epc

logs-radio-supervisor:
	docker compose logs -f radio-supervisor

logs-5g:
	docker compose -f docker-compose.5g.yml logs -f

logs-5g-core:
	docker compose -f docker-compose.5g.yml logs -f open5gs-5gc

logs-5g-gnb:
	docker compose -f docker-compose.5g.yml logs -f oai-gnb

logs-5g-ems-o5gc:
	docker compose -f docker-compose.5g.yml logs -f ems-o5gc

logs-5g-ems-gnb:
	docker compose -f docker-compose.5g.yml logs -f ems-gnb & \
	docker compose -f docker-compose.5g.yml exec oai-gnb sh -c 'tail -n 200 -f /var/log/nearRT-RIC.log /var/log/ems-gnb-metrics-xapp.log'

logs-5g-ue:
	docker compose -f docker-compose.5g.yml logs -f oai-nr-ue

net-check:
	bash build/scripts/check_ue_internet.sh

net-check-5g:
	bash build/scripts/5g_wait_ready.sh

netconf-keys:
	bash build/scripts/netconf_keys.sh

netconf-poll-gnb:
	bash build/scripts/gnb_metrics_poll.sh 127.0.0.1 8303 metrics $(POLL_INTERVAL)

netconf-poll-gnb-e2:
	bash build/scripts/gnb_metrics_poll.sh 127.0.0.1 8303 e2 0

netconf-poll-gnb-ues:
	bash build/scripts/gnb_metrics_poll.sh 127.0.0.1 8303 ues $(POLL_INTERVAL)

netconf-poll-gnb-kpis:
	bash build/scripts/gnb_metrics_poll.sh 127.0.0.1 8303 kpis $(POLL_INTERVAL)

netconf-poll-open5gs:
	bash build/scripts/open5gs_metrics_poll.sh 127.0.0.1 8304 all 0

netconf-poll-open5gs-amf:
	bash build/scripts/open5gs_metrics_poll.sh 127.0.0.1 8304 amf 0

netconf-poll-open5gs-smf:
	bash build/scripts/open5gs_metrics_poll.sh 127.0.0.1 8304 smf 0

netconf-poll-open5gs-upf:
	bash build/scripts/open5gs_metrics_poll.sh 127.0.0.1 8304 upf 0

netconf-poll-open5gs-pcf:
	bash build/scripts/open5gs_metrics_poll.sh 127.0.0.1 8304 pcf 0

netconf-poll-open5gs-metrics:
	bash build/scripts/open5gs_metrics_poll.sh 127.0.0.1 8304 amf-metrics 0

netconf-poll-open5gs-amf-metrics:
	bash build/scripts/open5gs_metrics_poll.sh 127.0.0.1 8304 amf-metrics 0

netconf-poll-open5gs-smf-metrics:
	bash build/scripts/open5gs_metrics_poll.sh 127.0.0.1 8304 smf-metrics 0

netconf-poll-open5gs-upf-metrics:
	bash build/scripts/open5gs_metrics_poll.sh 127.0.0.1 8304 upf-metrics 0

netconf-poll-open5gs-pcf-metrics:
	bash build/scripts/open5gs_metrics_poll.sh 127.0.0.1 8304 pcf-metrics 0

netconf-poll-open5gs-amf-performance:
	bash build/scripts/open5gs_metrics_poll.sh 127.0.0.1 8304 amf-performance 0

netconf-poll-open5gs-smf-performance:
	bash build/scripts/open5gs_metrics_poll.sh 127.0.0.1 8304 smf-performance 0

netconf-poll-open5gs-upf-performance:
	bash build/scripts/open5gs_metrics_poll.sh 127.0.0.1 8304 upf-performance 0

netconf-poll-open5gs-pcf-performance:
	bash build/scripts/open5gs_metrics_poll.sh 127.0.0.1 8304 pcf-performance 0

netconf-poll-open5gs-amf-info:
	bash build/scripts/open5gs_metrics_poll.sh 127.0.0.1 8304 amf-info 0

netconf-poll-open5gs-smf-info:
	bash build/scripts/open5gs_metrics_poll.sh 127.0.0.1 8304 smf-info 0

netconf-poll-open5gs-amf-dump:
	bash build/scripts/open5gs_metrics_poll.sh 127.0.0.1 8304 amf-dump 0

netconf-poll-open5gs-smf-dump:
	bash build/scripts/open5gs_metrics_poll.sh 127.0.0.1 8304 smf-dump 0

netconf-poll-open5gs-alarms:
	bash build/scripts/open5gs_metrics_poll.sh 127.0.0.1 8304 alarms $(POLL_INTERVAL)

netconf-poll-open5gs-amf-alarms:
	bash build/scripts/open5gs_metrics_poll.sh 127.0.0.1 8304 amf-alarms $(POLL_INTERVAL)

netconf-poll-open5gs-smf-alarms:
	bash build/scripts/open5gs_metrics_poll.sh 127.0.0.1 8304 smf-alarms $(POLL_INTERVAL)

netconf-poll-open5gs-upf-alarms:
	bash build/scripts/open5gs_metrics_poll.sh 127.0.0.1 8304 upf-alarms $(POLL_INTERVAL)

netconf-poll-open5gs-pcf-alarms:
	bash build/scripts/open5gs_metrics_poll.sh 127.0.0.1 8304 pcf-alarms $(POLL_INTERVAL)

# Demonstrate Open5GS alarms with the SYNTHETIC tool (forces a metric view via
# the EMS /inject endpoint).
# See build/scripts/o5gs_alarms/synthetic.sh. For REAL faults use the o5gs-alarm-* targets.
# e.g. make o5gs-synthetic SETUP=amf_reg_init_fail      # synthetic raise
#      make o5gs-synthetic-clear ALARM=amf_reg_init_fail # clear (reset NF)
#      make o5gs-inject-alarm NF=amf METRIC=<key> VALUE=<v>   # low-level set
o5gs-synthetic:
	bash build/scripts/o5gs_alarms/synthetic.sh raise $(ALARM) $(NF)
o5gs-synthetic-clear:
	bash build/scripts/o5gs_alarms/synthetic.sh clear $(ALARM) $(NF)
# Raise or clear EVERY synthetic-capable alarm in one go (debug/test sweep).
# Delta-only alarms (nf_cpu_saturation, nf_unexpected_restart,
# upf_n3_data_stagnation) are skipped - use their real o5gs-alarm-* targets.
o5gs-synthetic-all:
	bash build/scripts/o5gs_alarms/synthetic.sh all
o5gs-synthetic-clear-all:
	@bash build/scripts/o5gs_alarms/synthetic.sh clear-all
o5gs-inject-alarm:
	bash build/scripts/o5gs_alarms/inject.sh 127.0.0.1 18084 $(NF) $(METRIC) $(VALUE)
o5gs-inject-reset:
	bash build/scripts/o5gs_alarms/synthetic.sh reset $(NF)

# ---------------------------------------------------------------------------
# REAL Open5GS alarm scenarios (TS 28.111). These induce genuine faults on the
# The EMS raises real alarms from real metric changes:
#   o5gs-alarm-nf-down  NF=<amf|smf|upf|pcf>   halt one real NF (SIGSTOP) -> Alarm_O5GS_NF_Unreachable
#   o5gs-alarm-nf-up    NF=...                 resume it (SIGCONT) -> alarm clears
#   o5gs-alarm-all-down                        halt amf smf upf pcf -> many real alarms at once
#   o5gs-alarm-all-up                          resume all of them
#   o5gs-alarm-gnb-down                        stop 5G-OAI-GNB -> Alarm_O5GS_NGAP_Association
#   o5gs-alarm-gnb-up                          start it again -> alarm clears
#   o5gs-alarm-status                          poll the Active Alarm List via NETCONF
#   o5gs-alarm-demo                            scripted raise + clear cycle end-to-end
# ---------------------------------------------------------------------------
o5gs-alarm-nf-down:
	bash build/scripts/o5gs_alarms/scenario.sh nf-down $(NF)
o5gs-alarm-nf-up:
	bash build/scripts/o5gs_alarms/scenario.sh nf-up $(NF)
o5gs-alarm-all-down:
	bash build/scripts/o5gs_alarms/scenario.sh all-down
o5gs-alarm-all-up:
	bash build/scripts/o5gs_alarms/scenario.sh all-up
o5gs-alarm-gnb-down:
	bash build/scripts/o5gs_alarms/scenario.sh gnb-down
o5gs-alarm-gnb-up:
	bash build/scripts/o5gs_alarms/scenario.sh gnb-up
o5gs-alarm-status:
	POLL_INTERVAL=0 bash build/scripts/open5gs_metrics_poll.sh 127.0.0.1 8304 alarms 0
o5gs-alarm-demo:
	bash build/scripts/o5gs_alarms/scenario.sh all-down
	@echo "== halted NFs; waiting for alarm raise =="
	sleep 12
	POLL_INTERVAL=0 bash build/scripts/open5gs_metrics_poll.sh 127.0.0.1 8304 alarms 0
	bash build/scripts/o5gs_alarms/scenario.sh all-up
	@echo "== resumed NFs; waiting for alarm clear =="
	sleep 16
	POLL_INTERVAL=0 bash build/scripts/open5gs_metrics_poll.sh 127.0.0.1 8304 alarms 0

netconf-poll-enb1:
	NETCONF_EMS_CONTAINER=EMS-ENB-1 bash build/scripts/netconf_poll.sh 127.0.0.1 8301 $(POLL_INTERVAL) get

netconf-poll-enb2:
	NETCONF_EMS_CONTAINER=EMS-ENB-2 bash build/scripts/netconf_poll.sh 127.0.0.1 8302 $(POLL_INTERVAL) get

netconf-poll-enb1-nrm:
	NETCONF_EMS_CONTAINER=EMS-ENB-1 NETCONF_NRM_MANAGED_ELEMENT=enb1 bash build/scripts/netconf_poll.sh 127.0.0.1 8301 $(POLL_INTERVAL) get-nrm

netconf-poll-enb2-nrm:
	NETCONF_EMS_CONTAINER=EMS-ENB-2 NETCONF_NRM_MANAGED_ELEMENT=enb2 bash build/scripts/netconf_poll.sh 127.0.0.1 8302 $(POLL_INTERVAL) get-nrm

netconf-poll-enb1-nrm-cells:
	NETCONF_EMS_CONTAINER=EMS-ENB-1 NETCONF_NRM_MANAGED_ELEMENT=enb1 bash build/scripts/netconf_poll.sh 127.0.0.1 8301 $(POLL_INTERVAL) get-nrm-cells

netconf-poll-enb2-nrm-cells:
	NETCONF_EMS_CONTAINER=EMS-ENB-2 NETCONF_NRM_MANAGED_ELEMENT=enb2 bash build/scripts/netconf_poll.sh 127.0.0.1 8302 $(POLL_INTERVAL) get-nrm-cells

netconf-hold-lock-enb1:
	NETCONF_EMS_CONTAINER=EMS-ENB-1 bash build/scripts/netconf_poll.sh 127.0.0.1 8301 1 hold-lock-candidate $(LOCK_SECONDS)

netconf-hold-lock-enb2:
	NETCONF_EMS_CONTAINER=EMS-ENB-2 bash build/scripts/netconf_poll.sh 127.0.0.1 8302 1 hold-lock-candidate $(LOCK_SECONDS)

nbi-edit-enb1-nprb:
	NETCONF_EMS_CONTAINER=EMS-ENB-1 NETCONF_NRM_MANAGED_ELEMENT=enb1 bash build/scripts/netconf_config_edit.sh 127.0.0.1 8301 n_prb $(NPRB) commit

nbi-edit-enb2-nprb:
	NETCONF_EMS_CONTAINER=EMS-ENB-2 NETCONF_NRM_MANAGED_ELEMENT=enb2 bash build/scripts/netconf_config_edit.sh 127.0.0.1 8302 n_prb $(NPRB) commit

tca-inject-enb1:
	bash build/scripts/tca_inject_metric.sh 127.0.0.1 18081 "$(TCA_MOI_ENB1)" "$(TCA_METRIC)" "$(TCA_VALUE)" "$(TCA_REPEAT)" "$(TCA_DELAY)"

tca-inject-enb2:
	bash build/scripts/tca_inject_metric.sh 127.0.0.1 18082 "$(TCA_MOI_ENB2)" "$(TCA_METRIC)" "$(TCA_VALUE)" "$(TCA_REPEAT)" "$(TCA_DELAY)"

restart-enb-by-serial:
	@if [ -z "$(SERIAL)" ]; then echo "Usage: make restart-enb-by-serial SERIAL='<enb_serial>'"; exit 2; fi
	bash build/scripts/restart_enb_by_serial.sh "$(SERIAL)"

restart-radio-pair1:
	bash build/scripts/restart_radio_pair.sh 1

restart-radio-pair2:
	bash build/scripts/restart_radio_pair.sh 2

iperf-ue1-dl:
	bash build/scripts/iperf_ue.sh UE-1 dl

iperf-ue1-ul:
	bash build/scripts/iperf_ue.sh UE-1 ul

iperf-ue2-dl:
	bash build/scripts/iperf_ue.sh UE-2 dl

iperf-ue2-ul:
	bash build/scripts/iperf_ue.sh UE-2 ul

iperf-5g-dl:
	IPERF_DURATION=$(IPERF_DURATION) bash build/scripts/5g_iperf.sh dl

iperf-5g-ul:
	IPERF_DURATION=$(IPERF_DURATION) bash build/scripts/5g_iperf.sh ul

clean:
	$(MAKE) -C externals/lte-element-manager clean
	rm -rf externals/lte-element-manager/third_party externals/lte-element-manager/.local
	rm -rf .artifacts

clean-5g:
	docker compose -f docker-compose.5g.yml down -t $(DOWN_TIMEOUT) --remove-orphans -v || true

distclean: clean
	@true

# Per-alarm scenarios (raise + restore).
#
# Every alarm ships a matching pair (REAL fault -> real scraped counter moves):
#   o5gs-alarm-<name>   - break it (SIGSTOP, gNB stop, iptables N4/N3 drop, or a
#                         subscriber-DB edit), then wait for the AlarmRecord.
#   o5gs-restore-<name> - undo EXACTLY the fault and confirm the alarm is CLEARED.
# o5gs-alarm-nf-unreachable / o5gs-restore-nf-unreachable take NF=<amf|smf|upf|pcf>;
# subscriber-DB scenarios take SUBSCRIBER_IMSI=<imsi>. Every scenario also runs
# out-of-the-box with NO parameters: subscriber-DB ones default to the seeded
# subscriber (208990100001100) and NF defaults to amf.
# -----------------------------------------------------------------------------
o5gs_alarms_dir := build/scripts/o5gs_alarms

# REAL fault scenarios: induce a fault, wait for the AlarmRecord.

o5gs-alarm-nf-unreachable:
	@bash $(o5gs_alarms_dir)/nf_unreachable/raise.sh $(NF)
o5gs-restore-nf-unreachable:
	@bash $(o5gs_alarms_dir)/nf_unreachable/restore.sh $(NF)

o5gs-alarm-ngap-sctp-assoc-down:
	@bash $(o5gs_alarms_dir)/ngap_sctp_assoc_down/raise.sh $(NF)
o5gs-restore-ngap-sctp-assoc-down:
	@bash $(o5gs_alarms_dir)/ngap_sctp_assoc_down/restore.sh $(NF)

o5gs-alarm-amf-gnb-count-dropped:
	@bash $(o5gs_alarms_dir)/amf_gnb_count_dropped/raise.sh $(NF)
o5gs-restore-amf-gnb-count-dropped:
	@bash $(o5gs_alarms_dir)/amf_gnb_count_dropped/restore.sh $(NF)

o5gs-alarm-amf-reg-init-fail:
	@bash $(o5gs_alarms_dir)/amf_reg_init_fail/raise.sh $(NF)
o5gs-restore-amf-reg-init-fail:
	@bash $(o5gs_alarms_dir)/amf_reg_init_fail/restore.sh $(NF)

o5gs-alarm-amf-reg-mob-fail:
	@bash $(o5gs_alarms_dir)/amf_reg_mob_fail/raise.sh $(NF)
o5gs-restore-amf-reg-mob-fail:
	@bash $(o5gs_alarms_dir)/amf_reg_mob_fail/restore.sh $(NF)

o5gs-alarm-amf-reg-period-fail:
	@bash $(o5gs_alarms_dir)/amf_reg_period_fail/raise.sh $(NF)
o5gs-restore-amf-reg-period-fail:
	@bash $(o5gs_alarms_dir)/amf_reg_period_fail/restore.sh $(NF)

o5gs-alarm-amf-reg-emerg-fail:
	@bash $(o5gs_alarms_dir)/amf_reg_emerg_fail/raise.sh $(NF)
o5gs-restore-amf-reg-emerg-fail:
	@bash $(o5gs_alarms_dir)/amf_reg_emerg_fail/restore.sh $(NF)

o5gs-alarm-amf-auth-reject-rate:
	@bash $(o5gs_alarms_dir)/amf_auth_reject_rate/raise.sh $(NF)
o5gs-restore-amf-auth-reject-rate:
	@bash $(o5gs_alarms_dir)/amf_auth_reject_rate/restore.sh $(NF)

o5gs-alarm-smf-pfcp-peer-loss:
	@bash $(o5gs_alarms_dir)/smf_pfcp_peer_loss/raise.sh $(NF)
o5gs-restore-smf-pfcp-peer-loss:
	@bash $(o5gs_alarms_dir)/smf_pfcp_peer_loss/restore.sh $(NF)

o5gs-alarm-smf-n4-sess-estab-fail:
	@bash $(o5gs_alarms_dir)/smf_n4_sess_estab_fail/raise.sh $(NF)
o5gs-restore-smf-n4-sess-estab-fail:
	@bash $(o5gs_alarms_dir)/smf_n4_sess_estab_fail/restore.sh $(NF)

o5gs-alarm-smf-n4-report-fail:
	@bash $(o5gs_alarms_dir)/smf_n4_report_fail/raise.sh $(NF)
o5gs-restore-smf-n4-report-fail:
	@bash $(o5gs_alarms_dir)/smf_n4_report_fail/restore.sh $(NF)

o5gs-alarm-upf-n4-sess-estab-fail:
	@bash $(o5gs_alarms_dir)/upf_n4_sess_estab_fail/raise.sh $(NF)
o5gs-restore-upf-n4-sess-estab-fail:
	@bash $(o5gs_alarms_dir)/upf_n4_sess_estab_fail/restore.sh $(NF)

o5gs-alarm-upf-n3-data-stagnation:
	@bash $(o5gs_alarms_dir)/upf_n3_data_stagnation/raise.sh $(NF)
o5gs-restore-upf-n3-data-stagnation:
	@bash $(o5gs_alarms_dir)/upf_n3_data_stagnation/restore.sh $(NF)

o5gs-alarm-nf-unexpected-restart:
	@bash $(o5gs_alarms_dir)/nf_unexpected_restart/raise.sh $(NF)
o5gs-restore-nf-unexpected-restart:
	@bash $(o5gs_alarms_dir)/nf_unexpected_restart/restore.sh $(NF)

o5gs-alarm-amf-zero-connected-ues:
	@bash $(o5gs_alarms_dir)/amf_zero_connected_ues/raise.sh $(NF)
o5gs-restore-amf-zero-connected-ues:
	@bash $(o5gs_alarms_dir)/amf_zero_connected_ues/restore.sh $(NF)

o5gs-alarm-smf-zero-active-ues:
	@bash $(o5gs_alarms_dir)/smf_zero_active_ues/raise.sh $(NF)
o5gs-restore-smf-zero-active-ues:
	@bash $(o5gs_alarms_dir)/smf_zero_active_ues/restore.sh $(NF)

o5gs-alarm-pdu-session-failure:
	@bash $(o5gs_alarms_dir)/pdu_session_failure/raise.sh $(NF)
o5gs-restore-pdu-session-failure:
	@bash $(o5gs_alarms_dir)/pdu_session_failure/restore.sh $(NF)

# Synthetic-only alarms (not forceable by a real fault): they use
# the /inject endpoint. Real vs synthetic is covered in docs/5g.

o5gs-alarm-amf-paging-fail-rate:
	@bash $(o5gs_alarms_dir)/synthetic.sh raise amf_paging_fail_rate
o5gs-restore-amf-paging-fail-rate:
	@bash $(o5gs_alarms_dir)/synthetic.sh clear amf_paging_fail_rate

o5gs-alarm-amf-conf-update-fail:
	@bash $(o5gs_alarms_dir)/synthetic.sh raise amf_conf_update_fail
o5gs-restore-amf-conf-update-fail:
	@bash $(o5gs_alarms_dir)/synthetic.sh clear amf_conf_update_fail

o5gs-alarm-amf-ran-ue-capacity:
	@bash $(o5gs_alarms_dir)/synthetic.sh raise amf_ran_ue_capacity
o5gs-restore-amf-ran-ue-capacity:
	@bash $(o5gs_alarms_dir)/synthetic.sh clear amf_ran_ue_capacity

o5gs-alarm-smf-active-bearer-limit:
	@bash $(o5gs_alarms_dir)/synthetic.sh raise smf_active_bearer_limit
o5gs-restore-smf-active-bearer-limit:
	@bash $(o5gs_alarms_dir)/synthetic.sh clear smf_active_bearer_limit

o5gs-alarm-upf-session-capacity:
	@bash $(o5gs_alarms_dir)/synthetic.sh raise upf_session_capacity
o5gs-restore-upf-session-capacity:
	@bash $(o5gs_alarms_dir)/synthetic.sh clear upf_session_capacity

o5gs-alarm-smf-gtpv1c-parse-error:
	@bash $(o5gs_alarms_dir)/synthetic.sh raise smf_gtpv1c_parse_error
o5gs-restore-smf-gtpv1c-parse-error:
	@bash $(o5gs_alarms_dir)/synthetic.sh clear smf_gtpv1c_parse_error

o5gs-alarm-smf-gtpv2c-parse-error:
	@bash $(o5gs_alarms_dir)/synthetic.sh raise smf_gtpv2c_parse_error
o5gs-restore-smf-gtpv2c-parse-error:
	@bash $(o5gs_alarms_dir)/synthetic.sh clear smf_gtpv2c_parse_error

o5gs-alarm-smf-gtp-new-node-failed:
	@bash $(o5gs_alarms_dir)/synthetic.sh raise smf_gtp_new_node_failed
o5gs-restore-smf-gtp-new-node-failed:
	@bash $(o5gs_alarms_dir)/synthetic.sh clear smf_gtp_new_node_failed

o5gs-alarm-nf-fd-exhaustion-warn:
	@bash $(o5gs_alarms_dir)/synthetic.sh raise nf_fd_exhaustion_warn
o5gs-restore-nf-fd-exhaustion-warn:
	@bash $(o5gs_alarms_dir)/synthetic.sh clear nf_fd_exhaustion_warn

o5gs-alarm-nf-fd-exhaustion-crit:
	@bash $(o5gs_alarms_dir)/synthetic.sh raise nf_fd_exhaustion_crit
o5gs-restore-nf-fd-exhaustion-crit:
	@bash $(o5gs_alarms_dir)/synthetic.sh clear nf_fd_exhaustion_crit

o5gs-alarm-nf-memory-leak-detect:
	@bash $(o5gs_alarms_dir)/synthetic.sh raise nf_memory_leak_detect
o5gs-restore-nf-memory-leak-detect:
	@bash $(o5gs_alarms_dir)/synthetic.sh clear nf_memory_leak_detect

o5gs-alarm-nf-cpu-saturation:
	@bash $(o5gs_alarms_dir)/synthetic.sh raise nf_cpu_saturation
o5gs-restore-nf-cpu-saturation:
	@bash $(o5gs_alarms_dir)/synthetic.sh clear nf_cpu_saturation

o5gs-alarm-policy-association-failure:
	@bash $(o5gs_alarms_dir)/synthetic.sh raise policy_association_failure
o5gs-restore-policy-association-failure:
	@bash $(o5gs_alarms_dir)/synthetic.sh clear policy_association_failure

o5gs-restore-all: o5gs-restore-nf-unreachable o5gs-restore-ngap-sctp-assoc-down \
	o5gs-restore-amf-gnb-count-dropped o5gs-restore-smf-pfcp-peer-loss \
	o5gs-restore-smf-n4-report-fail o5gs-restore-smf-n4-sess-estab-fail \
	o5gs-restore-upf-n4-sess-estab-fail o5gs-restore-upf-n3-data-stagnation

.PHONY: \
o5gs-alarm-nf-unreachable o5gs-restore-nf-unreachable \
o5gs-alarm-ngap-sctp-assoc-down o5gs-restore-ngap-sctp-assoc-down \
o5gs-alarm-amf-gnb-count-dropped o5gs-restore-amf-gnb-count-dropped \
o5gs-alarm-amf-reg-init-fail o5gs-restore-amf-reg-init-fail \
o5gs-alarm-amf-reg-mob-fail o5gs-restore-amf-reg-mob-fail \
o5gs-alarm-amf-reg-period-fail o5gs-restore-amf-reg-period-fail \
o5gs-alarm-amf-reg-emerg-fail o5gs-restore-amf-reg-emerg-fail \
o5gs-alarm-amf-auth-reject-rate o5gs-restore-amf-auth-reject-rate \
o5gs-alarm-amf-paging-fail-rate o5gs-restore-amf-paging-fail-rate \
o5gs-alarm-amf-conf-update-fail o5gs-restore-amf-conf-update-fail \
o5gs-alarm-amf-ran-ue-capacity o5gs-restore-amf-ran-ue-capacity \
o5gs-alarm-smf-pfcp-peer-loss o5gs-restore-smf-pfcp-peer-loss \
o5gs-alarm-smf-n4-sess-estab-fail o5gs-restore-smf-n4-sess-estab-fail \
o5gs-alarm-smf-n4-report-fail o5gs-restore-smf-n4-report-fail \
o5gs-alarm-upf-n4-sess-estab-fail o5gs-restore-upf-n4-sess-estab-fail \
o5gs-alarm-smf-active-bearer-limit o5gs-restore-smf-active-bearer-limit \
o5gs-alarm-upf-session-capacity o5gs-restore-upf-session-capacity \
o5gs-alarm-smf-gtpv1c-parse-error o5gs-restore-smf-gtpv1c-parse-error \
o5gs-alarm-smf-gtpv2c-parse-error o5gs-restore-smf-gtpv2c-parse-error \
o5gs-alarm-smf-gtp-new-node-failed o5gs-restore-smf-gtp-new-node-failed \
o5gs-alarm-nf-fd-exhaustion-warn o5gs-restore-nf-fd-exhaustion-warn \
o5gs-alarm-nf-fd-exhaustion-crit o5gs-restore-nf-fd-exhaustion-crit \
o5gs-alarm-nf-memory-leak-detect o5gs-restore-nf-memory-leak-detect \
o5gs-alarm-nf-cpu-saturation o5gs-restore-nf-cpu-saturation \
o5gs-alarm-nf-unexpected-restart o5gs-restore-nf-unexpected-restart \
o5gs-alarm-upf-n3-data-stagnation o5gs-restore-upf-n3-data-stagnation \
o5gs-alarm-amf-zero-connected-ues o5gs-restore-amf-zero-connected-ues \
o5gs-alarm-smf-zero-active-ues o5gs-restore-smf-zero-active-ues \
o5gs-alarm-pdu-session-failure o5gs-restore-pdu-session-failure \
o5gs-alarm-policy-association-failure o5gs-restore-policy-association-failure \
o5gs-restore-all
