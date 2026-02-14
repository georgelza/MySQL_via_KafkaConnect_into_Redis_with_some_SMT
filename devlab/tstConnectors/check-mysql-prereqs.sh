#!/bin/bash

# Complete MySQL Debezium Prerequisites Check Script
# Checks all requirements for Debezium MySQL connector

MYSQL_CONTAINER="${MYSQL_CONTAINER:-mysql}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-}"
MYSQL_USER="${MYSQL_USER:-tokenuser}"
MYSQL_DATABASE="${MYSQL_DATABASE:-tokenise}"
TABLE_NAME="${TABLE_NAME:-JNL_ACQ}"

echo "=================================================="
echo "MYSQL DEBEZIUM PREREQUISITES CHECK"
echo "=================================================="
echo "Container: ${MYSQL_CONTAINER}"
echo "Database:  ${MYSQL_DATABASE}"
echo "Table:     ${TABLE_NAME}"
echo "User:      ${MYSQL_USER}"
echo ""

# Step 0: Check if container is running
echo "STEP 0: Checking if MySQL container is running..."
echo "-----------------------------------"
if docker ps --format '{{.Names}}' | grep -q "^${MYSQL_CONTAINER}$"; then
    echo "✅ Container '${MYSQL_CONTAINER}' is RUNNING"
else
    echo "❌ Container '${MYSQL_CONTAINER}' is NOT running"
    if docker ps -a --format '{{.Names}}' | grep -q "^${MYSQL_CONTAINER}$"; then
        echo ""
        echo "Container exists but is stopped. Start it with:"
        echo "  docker start ${MYSQL_CONTAINER}"
        echo "  OR"
        echo "  docker-compose up -d mysql"
    else
        echo ""
        echo "Container does not exist. Start with:"
        echo "  docker-compose up -d mysql"
    fi
    exit 1
fi
echo ""

# Prompt for password if not set
if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
    echo "MySQL root password required for checks."
    read -s -p "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
    echo ""
    echo ""
fi

# Function to run MySQL command
run_mysql_cmd() {
    local cmd="$1"
    docker exec -i ${MYSQL_CONTAINER} mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "$cmd" 2>&1
}

# Step 1: Test MySQL connection
echo "STEP 1: Testing MySQL connection..."
echo "-----------------------------------"
TEST_RESULT=$(run_mysql_cmd "SELECT 1;" 2>&1)
if echo "$TEST_RESULT" | grep -q "ERROR 1045"; then
    echo "❌ MySQL authentication failed - incorrect password"
    exit 1
elif echo "$TEST_RESULT" | grep -q "ERROR"; then
    echo "❌ MySQL connection failed:"
    echo "$TEST_RESULT"
    exit 1
else
    echo "✅ MySQL connection successful"
fi
echo ""

# Step 2: Check binlog is enabled
echo "STEP 2: Checking if binlog is enabled..."
echo "-----------------------------------"
BINLOG_CHECK=$(run_mysql_cmd "SHOW VARIABLES LIKE 'log_bin';")
echo "$BINLOG_CHECK"
if echo "$BINLOG_CHECK" | grep -q "ON"; then
    echo "✅ Binary logging is ENABLED"
else
    echo "❌ Binary logging is DISABLED - THIS IS REQUIRED FOR DEBEZIUM!"
    echo ""
    echo "To enable, add to MySQL config (my.cnf or docker-compose.yml):"
    echo "  [mysqld]"
    echo "  server-id = 1"
    echo "  log_bin = mysql-bin"
    echo "  binlog_format = ROW"
    echo "  binlog_row_image = FULL"
    echo ""
fi
echo ""

# Step 3: Check binlog format
echo "STEP 3: Checking binlog format..."
echo "-----------------------------------"
BINLOG_FORMAT=$(run_mysql_cmd "SHOW VARIABLES LIKE 'binlog_format';")
echo "$BINLOG_FORMAT"
if echo "$BINLOG_FORMAT" | grep -q "ROW"; then
    echo "✅ Binlog format is ROW"
else
    echo "❌ Binlog format is NOT ROW - THIS IS REQUIRED FOR DEBEZIUM!"
    echo ""
    echo "To fix, add to MySQL config:"
    echo "  binlog_format = ROW"
    echo ""
fi
echo ""

# Step 4: Check binlog row image
echo "STEP 4: Checking binlog row image..."
echo "-----------------------------------"
BINLOG_ROW_IMAGE=$(run_mysql_cmd "SHOW VARIABLES LIKE 'binlog_row_image';")
echo "$BINLOG_ROW_IMAGE"
if echo "$BINLOG_ROW_IMAGE" | grep -q "FULL"; then
    echo "✅ Binlog row image is FULL"
else
    echo "⚠️  Binlog row image is not FULL (recommended: FULL)"
fi
echo ""

# Step 5: Check database exists
echo "STEP 5: Checking if database exists..."
echo "-----------------------------------"
DB_CHECK=$(run_mysql_cmd "SHOW DATABASES LIKE '${MYSQL_DATABASE}';")
if echo "$DB_CHECK" | grep -q "${MYSQL_DATABASE}"; then
    echo "✅ Database '${MYSQL_DATABASE}' exists"
else
    echo "❌ Database '${MYSQL_DATABASE}' does NOT exist"
    echo ""
    echo "Create it with:"
    echo "  docker exec -i ${MYSQL_CONTAINER} mysql -u root -p${MYSQL_ROOT_PASSWORD} -e \"CREATE DATABASE ${MYSQL_DATABASE};\""
fi
echo ""

# Step 6: Check user exists and permissions
echo "STEP 6: Checking user permissions..."
echo "-----------------------------------"
USER_EXISTS=$(run_mysql_cmd "SELECT User, Host FROM mysql.user WHERE User='${MYSQL_USER}';" 2>&1)
if echo "$USER_EXISTS" | grep -q "${MYSQL_USER}"; then
    echo "✅ User '${MYSQL_USER}' exists"
    echo ""
    echo "User grants:"
    USER_GRANTS=$(run_mysql_cmd "SHOW GRANTS FOR '${MYSQL_USER}'@'%';")
    echo "$USER_GRANTS"
    echo ""
    
    if echo "$USER_GRANTS" | grep -q "REPLICATION SLAVE"; then
        echo "✅ User has REPLICATION SLAVE permission"
    else
        echo "❌ User MISSING REPLICATION SLAVE permission - THIS IS REQUIRED!"
        echo ""
        echo "To fix, run:"
        echo "  docker exec -i ${MYSQL_CONTAINER} mysql -u root -p${MYSQL_ROOT_PASSWORD} -e \"GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO '${MYSQL_USER}'@'%'; FLUSH PRIVILEGES;\""
        echo ""
    fi
    
    if echo "$USER_GRANTS" | grep -q "REPLICATION CLIENT"; then
        echo "✅ User has REPLICATION CLIENT permission"
    else
        echo "❌ User MISSING REPLICATION CLIENT permission - THIS IS REQUIRED!"
    fi
else
    echo "❌ User '${MYSQL_USER}' does NOT exist"
    echo ""
    echo "Create user with:"
    echo "  docker exec -i ${MYSQL_CONTAINER} mysql -u root -p${MYSQL_ROOT_PASSWORD} -e \"CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY 'tokenpw'; GRANT SELECT, SHOW DATABASES, REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO '${MYSQL_USER}'@'%'; FLUSH PRIVILEGES;\""
fi
echo ""

# Step 7: Check table exists
echo "STEP 7: Checking if table exists..."
echo "-----------------------------------"
TABLE_EXISTS=$(run_mysql_cmd "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${MYSQL_DATABASE}' AND table_name='${TABLE_NAME}';" 2>&1 | grep -o "[0-9]" | head -1)
if [ "$TABLE_EXISTS" = "1" ]; then
    echo "✅ Table '${TABLE_NAME}' exists in database '${MYSQL_DATABASE}'"
    echo ""
    echo "Table structure (first 10 columns):"
    run_mysql_cmd "USE ${MYSQL_DATABASE}; DESCRIBE ${TABLE_NAME};" | head -12
    echo ""
    echo "Row count:"
    run_mysql_cmd "SELECT COUNT(*) FROM ${MYSQL_DATABASE}.${TABLE_NAME};" 2>&1 | grep -v COUNT
else
    echo "❌ Table '${TABLE_NAME}' does NOT exist in database '${MYSQL_DATABASE}'"
    echo ""
    echo "Available tables:"
    run_mysql_cmd "SHOW TABLES FROM ${MYSQL_DATABASE};"
fi
echo ""

# Step 8: Check Kafka Connect
echo "STEP 8: Checking Kafka Connect..."
echo "-----------------------------------"
CONNECT_STATUS=$(curl -s http://localhost:8083/ 2>&1)
if echo "$CONNECT_STATUS" | grep -q "version"; then
    echo "✅ Kafka Connect is reachable"
    CONNECT_VERSION=$(echo "$CONNECT_STATUS" | jq -r '.version' 2>/dev/null || echo "unknown")
    echo "   Version: $CONNECT_VERSION"
else
    echo "❌ Kafka Connect is NOT reachable at http://localhost:8083"
    echo "   Make sure Kafka Connect container is running"
fi
echo ""

# Summary
echo "=================================================="
echo "SUMMARY"
echo "=================================================="
echo ""

# Count issues
ISSUES=0

if ! echo "$BINLOG_CHECK" | grep -q "ON"; then
    echo "❌ Binary logging is disabled"
    ISSUES=$((ISSUES+1))
fi

if ! echo "$BINLOG_FORMAT" | grep -q "ROW"; then
    echo "❌ Binlog format is not ROW"
    ISSUES=$((ISSUES+1))
fi

if ! echo "$DB_CHECK" | grep -q "${MYSQL_DATABASE}"; then
    echo "❌ Database does not exist"
    ISSUES=$((ISSUES+1))
fi

if ! echo "$USER_EXISTS" | grep -q "${MYSQL_USER}"; then
    echo "❌ User does not exist"
    ISSUES=$((ISSUES+1))
elif ! echo "$USER_GRANTS" | grep -q "REPLICATION SLAVE"; then
    echo "❌ User missing REPLICATION permissions"
    ISSUES=$((ISSUES+1))
fi

if [ "$TABLE_EXISTS" != "1" ]; then
    echo "❌ Table does not exist"
    ISSUES=$((ISSUES+1))
fi

if ! echo "$CONNECT_STATUS" | grep -q "version"; then
    echo "❌ Kafka Connect not reachable"
    ISSUES=$((ISSUES+1))
fi

echo ""
if [ $ISSUES -eq 0 ]; then
    echo "✅ ALL CHECKS PASSED! Ready to create Debezium connector."
    echo ""
    echo "Next step: Run the connector creation script:"
    echo "  ./jnl_acq_constant_key_AZ1.sh"
else
    echo "⚠️  Found $ISSUES issue(s) that need to be fixed before creating the connector."
    echo ""
    echo "Review the output above and fix the issues marked with ❌"
fi
echo ""
