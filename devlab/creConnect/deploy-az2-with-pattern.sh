#!/bin/bash
# //////////////////////////////////////////////////////////////////////////////////////////////////////
#
#       Project         :   Kafka Connect Source/Sink Connector SMT Function
#
#       File            :   deploy-az2-with-pattern.sh
#
#       Description     :   Kafka Connect Source/Sink Connector SMT Function
#
#       Created         :   Feb 2026
#
#       copyright       :   Copyright 2026, - G Leonard, georgelza@gmail.com
#
#       GIT Repo        :   https://github.com/georgelza/MySQL_via_KafkaConnect_into_Redis_with_some_SMT.git
#
#       Blog            :
#
#       Deploy AZ2 Redis Sink with Namespace Pattern
#       This script deploys the AZ2 connector with az2:card: prefix
#
#///////////////////////////////////////////////////////////////////////////////////////////////////////

export KAFKA_CONNECT_URL="http://localhost:8083"
export CONNECTOR_NAME="redis-sink-jnl-acq-az2"

# Kafka Configuration
export SOURCE_TOPIC="jnl_acq"
export KAFKA_KEY_FILTER="AZ2"

# Redis Configuration
export REDIS_HOST="redis"
export REDIS_PORT="6379"
export REDIS_DATABASE="1"  # AZ2 uses database 1
export REDIS_PASSWORD=""

# Field Selection
export REDIS_KEY_FIELD="cardNumber"
export REDIS_VALUE_FIELDS="acqJnlSeqNumber,tkcardNumber"

# 🆕 KEY PATTERN - Add az2:card: prefix
export REDIS_KEY_PATTERN="card:\${key}"

echo "=================================================="
echo "Deploying AZ* Redis Sink Connector"
echo "=================================================="
echo "Pattern: ${REDIS_KEY_PATTERN}"
echo "Example Key: card:5555666677778888"
echo "Example Key: az2:card:5555666677778888"
echo ""

# Run the deployment script
./jnl_acq_redis_sink-SMT.sh

echo ""
echo "Verification Commands:"
echo "---------------------"
echo "# List all AZ2 keys"
echo "docker exec redis redis-cli -n 1 KEYS 'az2:card:*'"
echo ""
echo "# Get specific key"
echo "docker exec redis redis-cli -n 1 GET 'az2:card:5555666677778888'"
echo ""
echo "# Count AZ2 keys"
echo "docker exec redis redis-cli -n 1 --scan --pattern 'az2:card:*' | wc -l"
