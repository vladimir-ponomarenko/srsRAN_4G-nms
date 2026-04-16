-include .env
export

.PHONY: help submodules lte-element-manager-clone netconf-client build build-fast build-ems build-enb build-ems-fast build-enb-fast pull-images up down restart ue1-shell ue2-shell enb1-shell enb2-shell epc-shell ems1-shell ems2-shell logs logs-all logs-epc logs-enb1 logs-enb2 logs-ue1 logs-ue2 logs-ems1 logs-ems2 logs-radio-supervisor net-check netconf-keys netconf-poll-enb1 netconf-poll-enb2 netconf-poll-enb1-nrm netconf-poll-enb2-nrm netconf-poll-enb1-nrm-cells netconf-poll-enb2-nrm-cells nbi-edit-enb1-nprb nbi-edit-enb2-nprb restart-enb-by-serial restart-radio-pair1 restart-radio-pair2 iperf-epc-server iperf-ue1-server iperf-ue2-server iperf-ue1-dl iperf-ue1-ul iperf-ue2-dl iperf-ue2-ul clean distclean

help:
	@echo "Usage: make [build|up|down|restart|ue1-shell|ue2-shell|enb1-shell|enb2-shell|epc-shell|ems1-shell|ems2-shell|logs|logs-all|logs-epc|logs-enb1|logs-enb2|logs-ue1|logs-ue2|logs-ems1|logs-ems2|net-check|iperf-epc-server|iperf-ue1-server|iperf-ue2-server|iperf-ue1-dl|iperf-ue1-ul|iperf-ue2-dl|iperf-ue2-ul]"

POLL_INTERVAL ?= 1
SERIAL ?=
NPRB ?= 50
DOWN_TIMEOUT ?= 10

lte-element-manager-clone: submodules
	$(MAKE) -C externals/lte-element-manager clone

netconf-client: lte-element-manager-clone
	$(MAKE) -C externals/lte-element-manager netconf-client

build: submodules lte-element-manager-clone pull-images
	DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker compose build

build-fast: submodules lte-element-manager-clone
	DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker compose build

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

submodules:
	git submodule sync --recursive
	git submodule update --init --recursive --depth 1

up: submodules
	docker compose up -d

down:
	docker compose down -t $(DOWN_TIMEOUT)

restart: down up

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

logs-radio-supervisor:
	docker compose logs -f radio-supervisor

net-check:
	bash build/scripts/check_ue_internet.sh

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

nbi-edit-enb1-nprb:
	NETCONF_EMS_CONTAINER=EMS-ENB-1 NETCONF_NRM_MANAGED_ELEMENT=enb1 bash build/scripts/netconf_config_edit.sh 127.0.0.1 8301 n_prb $(NPRB) commit

nbi-edit-enb2-nprb:
	NETCONF_EMS_CONTAINER=EMS-ENB-2 NETCONF_NRM_MANAGED_ELEMENT=enb2 bash build/scripts/netconf_config_edit.sh 127.0.0.1 8302 n_prb $(NPRB) commit

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

clean:
	$(MAKE) -C externals/lte-element-manager clean
	rm -rf externals/lte-element-manager/third_party externals/lte-element-manager/.local
	rm -rf .artifacts

distclean: clean
	@true
