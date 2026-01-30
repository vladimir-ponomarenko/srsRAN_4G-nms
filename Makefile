include .env
export

.PHONY: help build up down restart ue1-shell ue2-shell epc-shell logs net-check

help:
	@echo "Usage: make [build|up|down|restart|ue1-shell|ue2-shell|epc-shell|logs|net-check]"

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

epc-shell:
	docker exec -it EPC bash

logs:
	docker compose logs -f srsenb-1

net-check:
	bash build/scripts/check_ue_internet.sh
