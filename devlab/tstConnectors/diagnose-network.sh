#!/bin/bash

echo "=================================================="
echo "KAFKA CONNECT NETWORK DIAGNOSTICS"
echo "=================================================="
echo ""

# Step 1: Check if topic exists from broker perspective
echo "STEP 1: Checking topics from BROKER container"
echo "-----------------------------------"
echo "All topics:"
docker exec broker kafka-topics --bootstrap-server localhost:9092 --list 2>&1 | grep -E "(schema-history|avro_jnl)" || echo "No matching topics found"
echo ""

echo "Schema history topic details:"
docker exec broker kafka-topics --bootstrap-server localhost:9092 --describe --topic schema-history-jnl-acq 2>&1
echo ""

# Step 2: Check network from connect container
echo "STEP 2: Checking network from CONNECT container"
echo "-----------------------------------"
echo "Can connect reach broker by hostname?"
docker exec connect ping -c 2 broker 2>&1 || echo "Ping failed"
echo ""

echo "Can connect reach broker:9092?"
docker exec connect nc -zv broker 9092 2>&1 || echo "Port check failed"
echo ""

echo "Can connect reach broker:29092?"
docker exec connect nc -zv broker 29092 2>&1 || echo "Port check failed"
echo ""

# Step 3: Check what bootstrap servers connect is using
echo "STEP 3: Checking Kafka Connect worker configuration"
echo "-----------------------------------"
echo "Looking for bootstrap.servers in connect container:"
docker exec connect cat /etc/kafka-connect/kafka-connect.properties 2>/dev/null | grep bootstrap || echo "Config file not found"
echo ""

# Step 4: Check connector configuration
echo "STEP 4: Current connector configuration"
echo "-----------------------------------"
CONN_CONFIG=$(curl -s http://localhost:8083/connectors/mysql-source-jnl-acq-az1 2>&1)
echo "$CONN_CONFIG" | jq '.config | {
  "schema.history.internal.kafka.bootstrap.servers": ."schema.history.internal.kafka.bootstrap.servers",
  "schema.history.internal.kafka.topic": ."schema.history.internal.kafka.topic"
}' 2>/dev/null || echo "Could not retrieve connector config"
echo ""

# Step 5: Try to list topics from connect container
echo "STEP 5: Can CONNECT container see Kafka topics?"
echo "-----------------------------------"
echo "Trying broker:9092:"
docker exec connect kafka-topics --bootstrap-server broker:9092 --list --command-config /dev/null 2>&1 | head -20 || echo "Failed with broker:9092"
echo ""

echo "Trying broker:29092:"
docker exec connect kafka-topics --bootstrap-server broker:29092 --list --command-config /dev/null 2>&1 | head -20 || echo "Failed with broker:29092"
echo ""

echo "Trying localhost:9092:"
docker exec connect kafka-topics --bootstrap-server localhost:9092 --list --command-config /dev/null 2>&1 | head -20 || echo "Failed with localhost:9092"
echo ""

# Step 6: Check docker network
echo "STEP 6: Docker network configuration"
echo "-----------------------------------"
echo "Connect container network:"
docker inspect connect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}} ({{.NetworkID}}){{end}}' 2>&1
echo ""
echo "Broker container network:"
docker inspect broker --format '{{range .NetworkSettings.Networks}}{{.IPAddress}} ({{.NetworkID}}){{end}}' 2>&1
echo ""

# Step 7: Recommendations
echo "=================================================="
echo "DIAGNOSIS SUMMARY"
echo "=================================================="
echo ""
echo "Common causes of this issue:"
echo "1. Connect container using wrong bootstrap servers"
echo "2. Network isolation between containers"
echo "3. Kafka broker not advertising correct listener"
echo "4. Topic auto-creation disabled + manual topic not visible"
echo ""
echo "Next steps:"
echo "- Check if connect can reach broker (Step 2)"
echo "- Verify bootstrap servers in connector config (Step 4)"
echo "- Check if connect can list topics (Step 5)"
echo ""
