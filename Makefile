include .env
export

.PHONY: help build build-fast build-ems build-enb build-ems-fast build-enb-fast pull-images up down restart ue1-shell ue2-shell enb1-shell enb2-shell epc-shell ems1-shell ems2-shell logs logs-all logs-epc logs-enb1 logs-enb2 logs-ue1 logs-ue2 logs-ems1 logs-ems2 net-check netconf-poll-enb1 netconf-poll-enb2 iperf-epc-server iperf-ue1-server iperf-ue2-server iperf-ue1-dl iperf-ue1-ul iperf-ue2-dl iperf-ue2-ul

help:
	@echo "Usage: make [build|up|down|restart|ue1-shell|ue2-shell|enb1-shell|enb2-shell|epc-shell|ems1-shell|ems2-shell|logs|logs-all|logs-epc|logs-enb1|logs-enb2|logs-ue1|logs-ue2|logs-ems1|logs-ems2|net-check|iperf-epc-server|iperf-ue1-server|iperf-ue2-server|iperf-ue1-dl|iperf-ue1-ul|iperf-ue2-dl|iperf-ue2-ul]"

POLL_INTERVAL ?= 1

build: pull-images
	DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker compose build

build-fast:
	DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker compose build

build-ems: pull-images
	DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker compose build ems-enb1 ems-enb2

build-enb: pull-images
	DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker compose build srsenb-1 srsenb-2

build-ems-fast:
	DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker compose build ems-enb1 ems-enb2

build-enb-fast:
	DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker compose build srsenb-1 srsenb-2

pull-images:
	bash build/scripts/pull_base_images.sh

up:
	docker compose up -d

down:
	docker compose down

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

net-check:
	bash build/scripts/check_ue_internet.sh

netconf-poll-enb1:
	bash build/scripts/netconf_poll.sh 127.0.0.1 8301 $(POLL_INTERVAL) get

netconf-poll-enb2:
	bash build/scripts/netconf_poll.sh 127.0.0.1 8302 $(POLL_INTERVAL) get

iperf-ue1-dl:
	bash build/scripts/iperf_ue.sh UE-1 dl

iperf-ue1-ul:
	bash build/scripts/iperf_ue.sh UE-1 ul

iperf-ue2-dl:
	bash build/scripts/iperf_ue.sh UE-2 dl

iperf-ue2-ul:
	bash build/scripts/iperf_ue.sh UE-2 ul
