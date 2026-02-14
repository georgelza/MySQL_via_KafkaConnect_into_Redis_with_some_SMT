#!/bin/bash

# Quick connector status checker

CONNECTOR_NAME="${CONNECTOR_NAME:-mysql-source-jnl-acq-az1}"
KAFKA_CONNECT_URL="${KAFKA_CONNECT_URL:-http://localhost:8083}"

echo "=================================================="
echo "CONNECTOR STATUS CHECK"
echo "=================================================="
echo "Connector: ${CONNECTOR_NAME}"
echo ""

# Check if connector exists
echo "Checking if connector exists..."
CONNECTORS=$(curl -s ${KAFKA_CONNECT_URL}/connectors)
echo "All connectors: $CONNECTORS"
echo ""

if echo "$CONNECTORS" | grep -q "${CONNECTOR_NAME}"; then
    echo "✅ Connector exists"
    echo ""
    
    # Get detailed status
    echo "Detailed status:"
    echo "-----------------------------------"
    STATUS=$(curl -s ${KAFKA_CONNECT_URL}/connectors/${CONNECTOR_NAME}/status)
    echo "$STATUS" | jq '.'
    echo ""
    
    # Extract key info
    CONNECTOR_STATE=$(echo "$STATUS" | jq -r '.connector.state // "UNKNOWN"')
    TASK_COUNT=$(echo "$STATUS" | jq -r '.tasks | length')
    
    echo "Summary:"
    echo "  Connector State: $CONNECTOR_STATE"
    echo "  Task Count: $TASK_COUNT"
    
    if [ "$TASK_COUNT" = "0" ]; then
        echo ""
        echo "⚠️  WARNING: No tasks assigned yet"
        echo "   This usually means the connector is still initializing"
        echo "   Wait 10-20 seconds and check again"
    else
        TASK_STATE=$(echo "$STATUS" | jq -r '.tasks[0].state // "UNKNOWN"')
        echo "  Task 0 State: $TASK_STATE"
        
        if [ "$TASK_STATE" = "FAILED" ]; then
            echo ""
            echo "❌ Task failed. Error trace:"
            echo "$STATUS" | jq -r '.tasks[0].trace // "No trace available"' | head -30
        elif [ "$TASK_STATE" = "RUNNING" ]; then
            echo ""
            echo "✅ Connector is RUNNING!"
            echo ""
            echo "Test it by inserting data:"
            echo "  docker exec mysql mysql -u root -pdbpassword tokenise -e \"INSERT INTO JNL_ACQ (acquirerId, cardNumber, operationType, transLocalDate, transLocalTime, bankId) VALUES ('TEST001', '1234567890123456', 'PUR', '$(date +%m%d)', '$(date +%H%M%S)', 'BANK01');\""
            echo ""
            echo "Then consume:"
            echo "  kafka-console-consumer --bootstrap-server localhost:9092 --topic avro_jnl_acq --from-beginning --max-messages 1 --property print.key=true"
        fi
    fi
else
    echo "❌ Connector does NOT exist"
    echo ""
    echo "Create it with:"
    echo "  ./jnl_acq_source_NO_SCHEMA_HISTORY.sh"
fi

echo ""
echo "=================================================="
echo "KAFKA TOPICS"
echo "=================================================="
docker exec broker kafka-topics --bootstrap-server localhost:9092 --list 2>/dev/null | grep -E "(avro_jnl_acq|schema-history)" || echo "No relevant topics found"

echo ""
