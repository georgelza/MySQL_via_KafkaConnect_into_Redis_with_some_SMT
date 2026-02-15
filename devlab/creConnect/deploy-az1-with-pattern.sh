#!/bin/bash
# //////////////////////////////////////////////////////////////////////////////////////////////////////
#
#       Project         :   Kafka Connect Source/Sink Connector SMT Function
#
#       File            :   deploy-az1-with-pattern.sh
#
#       Description     :   Kafka Connect Source/Sink Connector SMT Function
#
#       Created         :   Feb 2026
#
#       copyright       :   Copyright 2026, - G Leonard, georgelza@gmail.com
#
#       GIT Repo        :   https://github.com/georgelza/MySQL_via_KafkaConnect_into_Redis_with_some_SMT.git
##
#       Deploy AZ1 Redis Sink with Namespace Pattern
#       This script deploys the AZ1 connector with az1:card: prefix
#
#///////////////////////////////////////////////////////////////////////////////////////////////////////

export KAFKA_CONNECT_URL="http://localhost:8083"
export CONNECTOR_NAME="redis-sink-jnl-acq-az1"

# Kafka Configuration
export SOURCE_TOPIC="jnl_acq"
export KAFKA_KEY_FILTER="AZ1"

# Redis Configuration
export REDIS_HOST="redis"
export REDIS_PORT="6379"
export REDIS_DATABASE="0"  # AZ1 uses database 0
export REDIS_PASSWORD=""

# Field Selection
export REDIS_KEY_FIELD="cardNumber"
export REDIS_VALUE_FIELDS="acqJnlSeqNumber,tkcardNumber"

# 🆕 KEY PATTERN - Add az1:card: prefix
export REDIS_KEY_PATTERN="az1:card:\${key}"

echo "=================================================="
echo "Deploying AZ* Redis Sink Connector"
echo "=================================================="
echo "Pattern: ${REDIS_KEY_PATTERN}"
echo "Example Key: card:5555666677778888"
echo "Example Key: az1:card:5555666677778888"
echo ""

# Run the deployment script
./jnl_acq_redis_sink-SMT.sh

echo ""
echo "Verification Commands:"
echo "---------------------"
echo "# List all AZ1 keys"
echo "docker exec redis redis-cli -n 0 KEYS 'az1:card:*'"
echo ""
echo "# Get specific key"
echo "docker exec redis redis-cli -n 0 GET 'az1:card:4111111111111111'"
echo ""
echo "# Count AZ1 keys"
echo "docker exec redis redis-cli -n 0 --scan --pattern 'az1:card:*' | wc -l"
