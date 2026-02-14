#!/bin/bash

CONNECTOR_NAME="${CONNECTOR_NAME:-mysql-source-jnl-acq-az1}"

echo "=================================================="
echo "CONNECTOR STATUS"
echo "=================================================="
echo ""

# Check connector status
STATUS=$(curl -s http://localhost:8083/connectors/${CONNECTOR_NAME}/status 2>&1)

if echo "$STATUS" | grep -q "error_code"; then
    echo "❌ Connector does not exist or error retrieving status"
    echo "$STATUS" | jq '.'
    echo ""
    echo "List of all connectors:"
    curl -s http://localhost:8083/connectors | jq '.'
else
    echo "Connector Status:"
    echo "$STATUS" | jq '.'
    
    # Extract task state
    TASK_STATE=$(echo "$STATUS" | jq -r '.tasks[0].state // "NO_TASK"')
    
    echo ""
    echo "Task State: $TASK_STATE"
    
    if [ "$TASK_STATE" = "RUNNING" ]; then
        echo "✅ Connector is RUNNING!"
        echo ""
        echo "Test by inserting data:"
        echo "docker exec mysql mysql -u root -pdbpassword tokenise -e \"INSERT INTO JNL_ACQ (acquirerId, cardNumber, operationType, transLocalDate, transLocalTime, bankId) VALUES ('TEST001', '1234567890123456', 'PUR', '0213', '160000', 'BANK01');\""
        echo ""
        echo "Consume messages:"
        echo "kafka-console-consumer --bootstrap-server localhost:9092 --topic avro_jnl_acq --from-beginning --max-messages 1 --property print.key=true"
    elif [ "$TASK_STATE" = "FAILED" ]; then
        echo "❌ Connector task FAILED"
        echo ""
        echo "Error trace:"
        echo "$STATUS" | jq -r '.tasks[0].trace // "No trace available"' | head -40
    fi
fi
