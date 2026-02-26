include .env
export

.PHONY: help build up down restart ue-shell logs

help:
	@echo "Usage: make [build|up|down|restart|ue-shell|logs]"

build:
	docker-compose build

up:
	docker-compose up -d

down:
	docker-compose down

restart: down up

ue-shell:
	docker exec -it nms-ue bash

logs:
	docker-compose logs -f srsenb-1