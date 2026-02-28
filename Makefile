include .env
export

.PHONY: help build up down restart ue1-shell ue2-shell enb1-shell enb2-shell epc-shell ems1-shell ems2-shell logs logs-all logs-epc logs-enb1 logs-enb2 logs-ue1 logs-ue2 logs-ems1 logs-ems2 net-check

help:
	@echo "Usage: make [build|up|down|restart|ue1-shell|ue2-shell|enb1-shell|enb2-shell|epc-shell|ems1-shell|ems2-shell|logs|logs-all|logs-epc|logs-enb1|logs-enb2|logs-ue1|logs-ue2|logs-ems1|logs-ems2|net-check]"

build:
	docker compose build

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
