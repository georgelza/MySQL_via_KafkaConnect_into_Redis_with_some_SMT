#!/bin/bash

# //////////////////////////////////////////////////////////////////////////////////////////////////////
#
#       Project         :   Kafka Connect Source/Sink Connector SMT Function
#
#       File            :   jnl_acq_redis_sink-SMT.sh
#
#       Description     :   Kafka Connect Source/Sink Connector SMT Function
#
#       Created     	  :   Feb 2026
#
#       copyright       :   Copyright 2026, - G Leonard, georgelza@gmail.com
#
#       GIT Repo        :   https://github.com/georgelza/MySQL_via_KafkaConnect_into_Redis_with_some_SMT.git
#
#       Blog            :
#
#       CUSTOM SMT Based Kafka REDIS Sink Connector with KEY_PATTERN Support
#
#       Filters by Kafka key (AZ1 or AZ2), extracts specific fields, formats Redis key, stores in Redis
#
#       Redis Structure:
#
#           Key:   Formatted key (e.g., "az1:card:4111111111111111" or "card:4111111111111111")
#           Value: JSON string {
#                "acqJnlSeqNumber": 12345, 
#                 "tkcardNumber":    "Special offer", 
#                "createdAt":       "2026-02-14T10:30:45.123Z
#            }
#
#       The idea is to deploy 2 of these, one per required REDIS datastore, i.e. all MySQL records originating from AZ1, with key=AZ1 being send to the AZ1 REDIS KV Datastore.
#       and likewise for MySQL sourced records from AZ2 going to the AZ2 Redis KV Datastore.
#
#       The REDIS datastores are configured with a (maxmemory 256mb) size to manage data retension based on space utilised,
#       Note REDIS keeps data based on LRU policy, NOT FIFO, to manage space used see <Project root>/redis/purge.sh
#
#       Redis Key Pattern
#       Examples:
#           "${key}"              -> "4111111111111111" (no change, default)
#           "card:${key}"         -> "card:4111111111111111"
#           "az1:card:${key}"     -> "az1:card:4111111111111111"
#           "${key}:v1"           -> "4111111111111111:v1"
#
#///////////////////////////////////////////////////////////////////////////////////////////////////////


set -e

KAFKA_CONNECT_URL="${KAFKA_CONNECT_URL:-http://localhost:8083}"
CONNECTOR_NAME="${CONNECTOR_NAME:-redis-sink-jnl-acq-az1}"

# Kafka Configuration
SOURCE_TOPIC="${SOURCE_TOPIC:-jnl_acq}"
KAFKA_KEY_FILTER="${KAFKA_KEY_FILTER:-AZ1}"

# Redis Configuration
REDIS_HOST="${REDIS_HOST:-redis}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_DATABASE="${REDIS_DATABASE:-0}"
REDIS_PASSWORD="${REDIS_PASSWORD:-}"

# Field Selection
REDIS_KEY_FIELD="${REDIS_KEY_FIELD:-cardNumber}"
# THE PAYLOAD
# Comma-separated list of fields to include in Redis value
REDIS_VALUE_FIELDS="${REDIS_VALUE_FIELDS:-acqJnlSeqNumber,tkcardNumber}"

REDIS_KEY_PATTERN="${REDIS_KEY_PATTERN:-card:\${key}}"
#export REDIS_KEY_PATTERN="az1:card:\${key}"

echo "=================================================="
echo "REDIS SINK CONNECTOR - ${KAFKA_KEY_FILTER}"
echo "=================================================="
echo "Source Topic: ${SOURCE_TOPIC}"
echo "Filter: Only messages with Kafka key = \"${KAFKA_KEY_FILTER}\""
echo ""
echo "Redis Structure:"
echo "  Key Field:    ${REDIS_KEY_FIELD}"
echo "  Key Pattern:  ${REDIS_KEY_PATTERN}"
echo "  Value Fields: ${REDIS_VALUE_FIELDS}"
echo "  Redis Server: ${REDIS_HOST}:${REDIS_PORT} (DB: ${REDIS_DATABASE})"
echo ""

# Delete old connector
echo "Deleting old connector (if exists)..."
curl -s -X DELETE ${KAFKA_CONNECT_URL}/connectors/${CONNECTOR_NAME} > /dev/null 2>&1
sleep 2

# Build Redis password config
REDIS_PASSWORD_CONFIG=""
if [ ! -z "$REDIS_PASSWORD" ]; then
    REDIS_PASSWORD_CONFIG="\"redis.password\": \"${REDIS_PASSWORD}\","
fi

# Create connector
CONNECTOR_CONFIG=$(cat <<EOF
    {
    "name": "${CONNECTOR_NAME}",
    "config": {
        "connector.class": "com.github.jcustenborder.kafka.connect.redis.RedisSinkConnector",
        "tasks.max": "1",
        "topics": "${SOURCE_TOPIC}",
        "redis.hosts": "${REDIS_HOST}:${REDIS_PORT}",
        "redis.database": "${REDIS_DATABASE}",
        ${REDIS_PASSWORD_CONFIG}
        "key.converter": "org.apache.kafka.connect.storage.StringConverter",
        "value.converter": "org.apache.kafka.connect.json.JsonConverter",
        "value.converter.schemas.enable": "false",
        "transforms": "filterKey,addTimestamp,selectFields,extractRedisKey,flattenKey,formatRedisKey,removeCardNumber,valueToJsonString",
        "transforms.filterKey.type": "com.token.kafka.connect.transforms.FilterByKafkaKey",
        "transforms.filterKey.key.value": "${KAFKA_KEY_FILTER}",
        "transforms.addTimestamp.type": "com.token.kafka.connect.transforms.AddTimestamp",
        "transforms.addTimestamp.timestamp.field": "createdAt",
        "transforms.addTimestamp.timestamp.format": "iso8601",
        "transforms.addTimestamp.timestamp.timezone": "Africa/Johannesburg",
        "transforms.selectFields.type": "org.apache.kafka.connect.transforms.ReplaceField\$Value",
        "transforms.selectFields.include": "${REDIS_VALUE_FIELDS},${REDIS_KEY_FIELD},createdAt",
        "transforms.extractRedisKey.type": "org.apache.kafka.connect.transforms.ValueToKey",
        "transforms.extractRedisKey.fields": "${REDIS_KEY_FIELD}",
        "transforms.flattenKey.type": "org.apache.kafka.connect.transforms.ExtractField\$Key",
        "transforms.flattenKey.field": "${REDIS_KEY_FIELD}",
        "transforms.formatRedisKey.type": "com.token.kafka.connect.transforms.RedisKeyFormatter",
        "transforms.formatRedisKey.key.pattern": "${REDIS_KEY_PATTERN}",
        "transforms.formatRedisKey.key.pattern.null.handling": "pass",
        "transforms.removeCardNumber.type": "org.apache.kafka.connect.transforms.ReplaceField\$Value",
        "transforms.removeCardNumber.exclude": "${REDIS_KEY_FIELD}",
        "transforms.valueToJsonString.type": "com.token.kafka.connect.transforms.ValueToJsonString"
        }
    }
EOF
)

echo "Creating connector..."
RESPONSE=$(echo "$CONNECTOR_CONFIG" | curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST ${KAFKA_CONNECT_URL}/connectors \
  -H "Content-Type: application/json" \
  -d @-)

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d':' -f2)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS:/d')

if [ "$HTTP_STATUS" != "201" ] && [ "$HTTP_STATUS" != "200" ]; then
    echo "❌ Failed (HTTP $HTTP_STATUS)"
    echo "$RESPONSE_BODY" | jq '.' 2>/dev/null || echo "$RESPONSE_BODY"
    exit 1
fi

echo "✅ Connector created"
echo ""

# Monitor
echo "Monitoring (30 seconds)..."
for i in {1..6}; do
    sleep 5
    STATUS=$(curl -s ${KAFKA_CONNECT_URL}/connectors/${CONNECTOR_NAME}/status)
    TASK_STATE=$(echo "$STATUS" | jq -r '.tasks[0].state // "NONE"')
    echo "Check $i/6: $TASK_STATE"
    
    if [ "$TASK_STATE" = "RUNNING" ]; then
        echo ""
        echo "=================================================="
        echo "✅ SUCCESS! REDIS SINK IS RUNNING"
        echo "=================================================="
        echo ""
        echo "How it works:"
        echo "  1. Reads from topic: ${SOURCE_TOPIC}"
        echo "  2. Filters: Only processes messages with Kafka key = \"${KAFKA_KEY_FILTER}\""
        echo "  3. Adds createdAt timestamp (ISO8601 format)"
        echo "  4. Extracts fields: ${REDIS_VALUE_FIELDS} (excludes ${REDIS_KEY_FIELD})"
        echo "  5. Formats Redis key using pattern: ${REDIS_KEY_PATTERN}"
        echo "  6. Stores in Redis"
        echo ""
        
        # Generate example key based on pattern
        EXAMPLE_CARD="4111111111111111"
        EXAMPLE_KEY=$(echo "${REDIS_KEY_PATTERN}" | sed "s/\${key}/${EXAMPLE_CARD}/g")
        
        echo "Example Redis entry:"
        echo "  redis> GET \"${EXAMPLE_KEY}\""
        echo "  {\"acqJnlSeqNumber\":12345,\"tkcardNumber\":\"10% off\",\"createdAt\":\"2026-02-14T10:30:45.123Z\"}"
        echo ""
        echo "Verify in Redis:"
        echo "  # List all keys"
        echo "  docker exec redis redis-cli -n ${REDIS_DATABASE} KEYS '*'"
        echo ""
        echo "  # Get a specific key (with pattern)"
        echo "  docker exec redis redis-cli -n ${REDIS_DATABASE} GET '${EXAMPLE_KEY}'"
        echo ""
        echo "  # Count total keys"
        echo "  docker exec redis redis-cli -n ${REDIS_DATABASE} DBSIZE"
        echo ""
        echo "  # Search by pattern"
        echo "  docker exec redis redis-cli -n ${REDIS_DATABASE} KEYS 'az1:card:*'"
        echo ""
        echo "Test by inserting into MySQL:"
        echo "  docker exec mysql mysql -u root -pdbpassword tokenise -e \\"
        echo "    \"INSERT INTO JNL_ACQ (acquirerId, cardNumber, tkcardNumber, operationType, transLocalDate, transLocalTime, bankId) \\"
        echo "    VALUES ('TEST', '9999888877776666', 'Test discount', 'PUR', '0214', '$(date +%H%M%S)', 'BANK01');\""
        echo ""
        
        # Generate example key for test
        TEST_KEY=$(echo "${REDIS_KEY_PATTERN}" | sed "s/\${key}/9999888877776666/g")
        echo "Then check Redis:"
        echo "  docker exec redis redis-cli -n ${REDIS_DATABASE} GET '${TEST_KEY}'"
        echo ""
        exit 0
    elif [ "$TASK_STATE" = "FAILED" ]; then
        echo ""
        echo "❌ Failed"
        echo "$STATUS" | jq -r '.tasks[0].trace' | head -30
        exit 1
    fi
done

echo ""
echo "⏳ Still starting. Check: curl ${KAFKA_CONNECT_URL}/connectors/${CONNECTOR_NAME}/status | jq"
