
.DEFAULT_GOAL := help
include .env

define HELP

Available commands:

- run: 		This will call core.
- deploy: 	This will create the Kafka topics, schema entries, all the Hive catalogs, Flink tables, flink inserts jobs etc.

- stop: 	Stop the project.
- start: 	Restart a Stopped the project.
- down: 	Tear down the project, clean directories.

- ps: 		Show all running containers.
- logs: 	Show logs.
- logsf: 	Show logs.
- watch: 	Watch logs.

endef

export HELP
help:
	@echo "$$HELP"
.PHONY: help


run:
	@echo "🚀 Starting core services (Kafka, MySQL Redis)..."
	docker compose -f docker-compose.yml -p token up -d \
		broker schema-registry control-center connect \
		mysql redis  \
		--remove-orphans

deploy: createtopics

createtopics:
	cd creTopics; ./creTopics.sh
	
stop:
	docker compose stop

start:
	docker compose start

down:	
	docker compose down
	cd data; rm -rf mysql
	cd data; rm -rf redis
	cd data; rm -rf kafka

ps:
	docker compose ps

logs:
	docker compose logs

logsf:
	docker compose logs -f

watch:
	watch docker compose ps

keys:
	kcat -b localhost:9092 -t jnl_acq -C -f '%k\n' -c 5

values:
	kcat -b localhost:9092 -t jnl_acq -C -o end -f 'Key: %k | Timestamp: %T\nValue: %s\n\n'

connect:
	docker compose exec connect /bin/bash
