#!/bin/bash

# CUSTOM SMT Based Kafka MySQL Source Connector
#
# - Filters: Only publishes if cardNumber AND tkcardNumber are populated
# - Key:     Plain string "AZ1" (not JSON, not Struct)
#
# The idea is 2 of these can be deployed, one per MySQL source, each inbound stream labelled by either AZ1 or AZ2 as original source.
#

set -e

CONNECTOR_NAME="${CONNECTOR_NAME:-mysql-source-jnl-acq-az1}"
CONSTANT_KEY="${CONSTANT_KEY:-AZ1}"

# MySQL Configuration
MYSQL_HOST="${MYSQL_HOST:-mysql}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-tokenuser}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-tokenpw}"
MYSQL_DATABASE="${MYSQL_DATABASE:-tokenise}"
TABLE_NAME="${TABLE_NAME:-JNL_ACQ}"

# Kafka Configuration
KAFKA_BOOTSTRAP_SERVERS="${KAFKA_BOOTSTRAP_SERVERS:-broker:29092}"
KAFKA_CONNECT_URL="${KAFKA_CONNECT_URL:-http://localhost:8083}"
TARGET_TOPIC="${TARGET_TOPIC:-jnl_acq}"
MYSQL_HOST_ID="${MYSQL_HOST_ID:-184054}"
MYSQL_HOST_NAME="${MYSQL_HOST_NAME:-mysql}"
SCHEMA_HISTORY_TOPIC="${SCHEMA_HISTORY_TOPIC:-schema-history-jnl-acq}"

# Filter Configuration
FILTER_FIELDS="${FILTER_FIELDS:-cardNumber,tkcardNumber}"
FILTER_MODE="${FILTER_MODE:-all}"

echo "=================================================="
echo "CONNECTOR WITH CUSTOM SMT"
echo "=================================================="
echo "Filter: Only messages with ${FILTER_FIELDS} populated"
echo "Key:    Plain string \"${CONSTANT_KEY}\""
echo "Topic:  ${TARGET_TOPIC}"
echo ""

# Delete old connector
echo "Deleting old connector (if exists)..."
curl -s -X DELETE ${KAFKA_CONNECT_URL}/connectors/${CONNECTOR_NAME} > /dev/null 2>&1
sleep 3

# Create connector with custom SMT
CONNECTOR_CONFIG=$(cat <<EOF
{
  "name": "${CONNECTOR_NAME}",
  "config": {
    "connector.class": "io.debezium.connector.mysql.MySqlConnector",
    "tasks.max": "1",
    "database.hostname": "${MYSQL_HOST}",
    "database.port": "${MYSQL_PORT}",
    "database.user": "${MYSQL_USER}",
    "database.password": "${MYSQL_PASSWORD}",
    "database.server.id": "${MYSQL_HOST_ID}",
    "topic.prefix": "${MYSQL_HOST_NAME}",
    "database.include.list": "${MYSQL_DATABASE}",
    "table.include.list": "${MYSQL_DATABASE}.${TABLE_NAME}",
    "include.schema.changes": "false",
    "database.connectionTimeZone": "Africa/Johannesburg",
    "schema.history.internal.kafka.bootstrap.servers": "${KAFKA_BOOTSTRAP_SERVERS}",
    "schema.history.internal.kafka.topic": "${SCHEMA_HISTORY_TOPIC}",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "false",
    "transforms": "route,unwrap,addKeyField,extractKey,filterAndKey,removeKeyField",
    "transforms.route.type": "io.debezium.transforms.ByLogicalTableRouter",
    "transforms.route.topic.regex": "${MYSQL_HOST_NAME}.${MYSQL_DATABASE}.${TABLE_NAME}",
    "transforms.route.topic.replacement": "${TARGET_TOPIC}",
    "transforms.unwrap.type": "io.debezium.transforms.ExtractNewRecordState",
    "transforms.unwrap.drop.tombstones": "false",
    "transforms.unwrap.delete.handling.mode": "rewrite",
    "transforms.addKeyField.type": "org.apache.kafka.connect.transforms.InsertField\$Value",
    "transforms.addKeyField.static.field": "key",
    "transforms.addKeyField.static.value": "${CONSTANT_KEY}",
    "transforms.extractKey.type": "org.apache.kafka.connect.transforms.ValueToKey",
    "transforms.extractKey.fields": "key",
    "transforms.filterAndKey.type": "com.token.kafka.connect.transforms.FilterAndExtractKey",
    "transforms.filterAndKey.key.field": "key",
    "transforms.filterAndKey.filter.fields": "${FILTER_FIELDS}",
    "transforms.filterAndKey.filter.mode": "${FILTER_MODE}",
    "transforms.removeKeyField.type": "org.apache.kafka.connect.transforms.ReplaceField\$Value",
    "transforms.removeKeyField.exclude": "key"
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
        echo "✅ SUCCESS! CONNECTOR IS RUNNING WITH CUSTOM SMT"
        echo "=================================================="
        echo ""
        echo "Configuration:"
        echo "  Topic: ${TARGET_TOPIC}"
        echo "  Key: \"${CONSTANT_KEY}\" (plain string)"
        echo "  Filter: ${FILTER_FIELDS} (mode: ${FILTER_MODE})"
        echo "  Value: Clean JSON"
        echo ""
        echo "Test 1: Insert WITH both fields (WILL be published):"
        echo "  docker exec mysql mysql -u root -pdbpassword tokenise -e \\"
        echo "    \"INSERT INTO JNL_ACQ (acquirerId, cardNumber, tkcardNumber, operationType, transLocalDate, transLocalTime, bankId) \\"
        echo "    VALUES ('TEST001', '4111111111111111', 'Discount applied', 'PUR', '0214', '$(date +%H%M%S)', 'BANK01');\""
        echo ""
        echo "Test 2: Insert WITHOUT tkcardNumber (WILL be filtered out):"
        echo "  docker exec mysql mysql -u root -pdbpassword tokenise -e \\"
        echo "    \"INSERT INTO JNL_ACQ (acquirerId, cardNumber, operationType, transLocalDate, transLocalTime, bankId) \\"
        echo "    VALUES ('TEST002', '4111111111111111', 'PUR', '0214', '$(date +%H%M%S)', 'BANK01');\""
        echo ""
        echo "Verify with kcat (should only see Test 1):"
        echo "  kcat -b localhost:9092 -t ${TARGET_TOPIC} -C -f 'Key: %k | cardNumber: ' -o -10 -e"
        echo ""
        echo "Check just the key:"
        echo "  kcat -b localhost:9092 -t ${TARGET_TOPIC} -C -f '%k\n' -c 5"
        echo ""
        echo "Expected key output: ${CONSTANT_KEY}"
        echo "                NOT: {\"key\":\"${CONSTANT_KEY}\"}"
        echo "                NOT: Struct{key=${CONSTANT_KEY}}"
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
