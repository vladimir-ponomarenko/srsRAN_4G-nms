-include .env
export

.PHONY: help submodules lte-element-manager-clone netconf-client build build-fast build-4g build-4g-fast build-5g build-5g-fast build-oai5g build-open5gs5g pull-images pull-images-5g up up-4g up-5g down down-4g down-5g restart restart-4g restart-5g build-ems build-enb build-ems-fast build-enb-fast ue1-shell ue2-shell enb1-shell enb2-shell epc-shell ems1-shell ems2-shell logs logs-all logs-epc logs-enb1 logs-enb2 logs-ue1 logs-ue2 logs-ems1 logs-ems2 logs-ems-epc logs-radio-supervisor logs-5g logs-5g-core logs-5g-gnb logs-5g-ue net-check net-check-5g netconf-keys netconf-poll-enb1 netconf-poll-enb2 netconf-poll-enb1-nrm netconf-poll-enb2-nrm netconf-poll-enb1-nrm-cells netconf-poll-enb2-nrm-cells netconf-hold-lock-enb1 netconf-hold-lock-enb2 nbi-edit-enb1-nprb nbi-edit-enb2-nprb tca-inject-enb1 tca-inject-enb2 restart-enb-by-serial restart-radio-pair1 restart-radio-pair2 iperf-epc-server iperf-ue1-server iperf-ue2-server iperf-ue1-dl iperf-ue1-ul iperf-ue2-dl iperf-ue2-ul iperf-5g-dl iperf-5g-ul clean clean-5g distclean

help:
	@echo "4G (default): make build && make up"
	@echo "5G RFSimulator: make build-5g && make up-5g && make net-check-5g"
	@echo "Useful 5G targets: logs-5g, logs-5g-core, logs-5g-gnb, logs-5g-ue, iperf-5g-dl, iperf-5g-ul, down-5g"

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

build-5g: submodules pull-images-5g build-oai5g build-open5gs5g

build-5g-fast: submodules
	DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker compose -f docker-compose.5g.yml build open5gs-5gc

build-open5gs5g: submodules
	DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker compose -f docker-compose.5g.yml build open5gs-5gc

build-oai5g: submodules
	DOCKER_BUILDKIT=1 docker build -t ran-base:latest -t srsran4g-nms-oai-ran-base:local -f build/oai5g/Dockerfile.base.rfsim.ubuntu externals/openairinterface5g
	DOCKER_BUILDKIT=1 docker build -t ran-build:latest -t srsran4g-nms-oai-ran-build:local -f build/oai5g/Dockerfile.build.rfsim.ubuntu externals/openairinterface5g
	DOCKER_BUILDKIT=1 docker build -t srsran4g-nms-oai-gnb:local -f build/oai5g/Dockerfile.gNB.rfsim.ubuntu externals/openairinterface5g
	DOCKER_BUILDKIT=1 docker build -t srsran4g-nms-oai-nr-ue:local -f build/oai5g/Dockerfile.nrUE.rfsim.ubuntu externals/openairinterface5g

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

logs-5g-ue:
	docker compose -f docker-compose.5g.yml logs -f oai-nr-ue

net-check:
	bash build/scripts/check_ue_internet.sh

net-check-5g:
	bash build/scripts/5g_wait_ready.sh

netconf-keys:
	bash build/scripts/netconf_keys.sh

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
