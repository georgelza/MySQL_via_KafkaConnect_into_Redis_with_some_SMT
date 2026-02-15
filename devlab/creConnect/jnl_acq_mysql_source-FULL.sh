#!/bin/bash

# //////////////////////////////////////////////////////////////////////////////////////////////////////
#
#       Project         :   Kafka Connect Source/Sink Connector SMT Function
#
#       File            :   jnl_acq_mysql_source-FULL.sh
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
#       This will extract the all records from the Source table and publish it onto the jnl_acq topic. 
#       It will additinall also add a key value based on the CONSTANT_KEY value passed in packaged as a JSON payload
#       i.e.:
#       key:  {"key": "AZ1"}
#
#///////////////////////////////////////////////////////////////////////////////////////////////////////

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
MYSQL_HOST_NAME="${MYSQL_HOST_NAME:-184054}"
SCHEMA_HISTORY_TOPIC="${SCHEMA_HISTORY_TOPIC:-schema-history-jnl-acq}"

echo "=================================================="
echo "CONNECTOR WITH CUSTOM SMT"
echo "=================================================="
echo "This will give you EXACTLY: \"${CONSTANT_KEY}\""
echo "Key:    Plain string \"${CONSTANT_KEY}\""
echo "Topic:  ${TARGET_TOPIC}"
echo ""

# Delete old connector
echo "Deleting old connector..."
curl -s -X DELETE ${KAFKA_CONNECT_URL}/connectors/${CONNECTOR_NAME} > /dev/null 2>&1
sleep 3

# Create connector with HoistField transform
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
      "database.server.name": "${MYSQL_HOST_NAME}",
      "topic.prefix": "${MYSQL_HOST}",
      "database.include.list": "${MYSQL_DATABASE}",
      "table.include.list": "${MYSQL_DATABASE}.${TABLE_NAME}",
      "include.schema.changes": "false",
      "database.connectionTimeZone": "Africa/Johannesburg",
      "schema.history.internal.kafka.bootstrap.servers": "${KAFKA_BOOTSTRAP_SERVERS}",
      "schema.history.internal.kafka.topic": "${SCHEMA_HISTORY_TOPIC}",
      "key.converter": "org.apache.kafka.connect.json.JsonConverter",
      "key.converter.schemas.enable": "false",
      "value.converter": "org.apache.kafka.connect.json.JsonConverter",
      "value.converter.schemas.enable": "false",
      "transforms": "route,unwrap,addKeyField,extractKey,removeKeyField",
      "transforms.route.type": "io.debezium.transforms.ByLogicalTableRouter",
      "transforms.route.topic.regex": "${MYSQL_HOST}.${MYSQL_DATABASE}.${TABLE_NAME}",
      "transforms.route.topic.replacement": "${TARGET_TOPIC}",
      "transforms.unwrap.type": "io.debezium.transforms.ExtractNewRecordState",
      "transforms.unwrap.drop.tombstones": "false",
      "transforms.unwrap.delete.handling.mode": "rewrite",
      "transforms.addKeyField.type": "org.apache.kafka.connect.transforms.InsertField\$Value",
      "transforms.addKeyField.static.field": "key",
      "transforms.addKeyField.static.value": "${CONSTANT_KEY}",
      "transforms.extractKey.type": "org.apache.kafka.connect.transforms.ValueToKey",
      "transforms.extractKey.fields": "key",
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
        echo "✅ SUCCESS! CONNECTOR IS RUNNING"
        echo "=================================================="
        echo ""
        echo "All messages will have key: {\"source_key\":\"${CONSTANT_KEY}\"}"
        echo ""
        echo "Output format:"
        echo "  Key:  \"${CONSTANT_KEY}\" (plain string)"
        echo "  Value: Clean JSON without schemas"
        echo ""
        echo "IMPORTANT: The key converter is StringConverter"
        echo "When you consume, you should see just: \"${CONSTANT_KEY}\""
        echo ""
        echo "Insert test data:"
        echo "  docker exec mysql mysql -u root -pdbpassword tokenise -e \\"
        echo "    \"INSERT INTO JNL_ACQ (acquirerId, cardNumber, operationType, transLocalDate, transLocalTime, bankId) \\"
        echo "    VALUES ('ACQ001', '1234567890123456', 'PUR', '1225', '153045', 'BNK001');\""
        echo ""
        echo "Consume messages with keys:"
        echo "  kafka-console-consumer --bootstrap-server broker:9092 \\"
        echo "    --topic ${TARGET_TOPIC} --from-beginning \\"
        echo "    --property print.key=true \\"
        echo "    --property key.separator=' => ' \\"
        echo "    --max-messages 5"
        echo ""
        echo "Or from host (if port 9092 exposed):"
        echo "  kafka-console-consumer --bootstrap-server localhost:9092 \\"
        echo "    --topic ${TARGET_TOPIC} --from-beginning \\"
        echo "    --property print.key=true \\"
        echo "    --property key.separator=' => ' \\"
        echo "    --max-messages 5"
        echo ""
        echo "=================================================="
        echo "USEFUL COMMANDS"
        echo "=================================================="
        echo ""
        echo "Check status:"
        echo "  curl ${KAFKA_CONNECT_URL}/connectors/${CONNECTOR_NAME}/status | jq"
        echo ""
        echo "View configuration:"
        echo "  curl ${KAFKA_CONNECT_URL}/connectors/${CONNECTOR_NAME} | jq"
        echo ""
        echo "Restart connector:"
        echo "  curl -X POST ${KAFKA_CONNECT_URL}/connectors/${CONNECTOR_NAME}/restart"
        echo ""
        echo "Delete connector:"
        echo "  curl -X DELETE ${KAFKA_CONNECT_URL}/connectors/${CONNECTOR_NAME}"
        echo ""
        echo "List all connectors:"
        echo "  curl ${KAFKA_CONNECT_URL}/connectors | jq"
        echo ""
        echo "View topics:"
        echo "  docker exec broker kafka-topics --bootstrap-server localhost:9092 --list"
        echo ""
        exit 0
    elif [ "$TASK_STATE" = "FAILED" ]; then
        echo ""
        echo "=================================================="
        echo "❌ CONNECTOR FAILED"
        echo "=================================================="        echo "$STATUS" | jq -r '.tasks[0].trace' | head -30
        exit 1
    fi
done