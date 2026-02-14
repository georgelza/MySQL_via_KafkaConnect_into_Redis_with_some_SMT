#!/bin/bash

export COMPOSE_PROJECT_NAME=token

docker compose exec broker kafka-topics \
 --create -topic jnl_acq \
 --bootstrap-server localhost:9092 \
 --partitions 2 \
 --replication-factor 1


# Lets list topics, excluding the default Confluent Platform topics
docker compose exec broker kafka-topics \
 --bootstrap-server localhost:9092 \
 --list | grep -v '_confluent' |grep -v '__' |grep -v '_schemas' | grep -v 'default' | grep -v 'docker-connect'

#  ./reg_jnl_acq_in.sh
#  ./reg_jnl_acq_out.sh
