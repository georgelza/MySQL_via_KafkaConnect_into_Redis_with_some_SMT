# Running Multiple Debezium Connectors on Same MySQL Source

## The Challenge

You want TWO connectors reading from the SAME MySQL database/table:
- Connector 1: Labels records with key "AZ1"
- Connector 2: Labels records with key "AZ2"

**Problem:** Debezium connectors will conflict if they share:
1. MySQL Server ID
2. Schema history topic
3. Connector name

## The Solution - Make Each Connector Unique

### Option 1: Different Server IDs (Recommended)

Each connector gets its own MySQL replication stream.

**Connector 1 (AZ1):**
```bash
CONNECTOR_NAME="mysql-source-jnl-acq-az1"
MYSQL_HOST_ID="184054"
SCHEMA_HISTORY_TOPIC="schema-history-jnl-acq-az1"
CONSTANT_KEY="AZ1"
```

**Connector 2 (AZ2):**
```bash
CONNECTOR_NAME="mysql-source-jnl-acq-az2"
MYSQL_HOST_ID="184055"  # DIFFERENT!
SCHEMA_HISTORY_TOPIC="schema-history-jnl-acq-az2"  # DIFFERENT!
CONSTANT_KEY="AZ2"
```

**Result:**
- ✅ Both connectors read ALL records
- ✅ Each labels records with different key (AZ1 vs AZ2)
- ✅ Records published TWICE to the same topic (once with each key)

### Option 2: Same Data, Different Sources (Alternative)

If you have TWO different MySQL databases with the SAME schema:

**Database 1 → Connector 1 → Key "AZ1"**
```bash
MYSQL_HOST="mysql-az1"
MYSQL_HOST_ID="184054"
CONSTANT_KEY="AZ1"
```

**Database 2 → Connector 2 → Key "AZ2"**
```bash
MYSQL_HOST="mysql-az2"
MYSQL_HOST_ID="184055"
CONSTANT_KEY="AZ2"
```

## Key Configuration Differences

### Must Be Unique Per Connector:

| Config | Connector 1 | Connector 2 | Purpose |
|--------|-------------|-------------|---------|
| `name` | `mysql-source-jnl-acq-az1` | `mysql-source-jnl-acq-az2` | Connector name |
| `database.server.id` | `184054` | `184055` | MySQL replication ID |
| `schema.history.internal.kafka.topic` | `schema-history-jnl-acq-az1` | `schema-history-jnl-acq-az2` | DDL tracking |
| `CONSTANT_KEY` | `AZ1` | `AZ2` | Message key |

### Can Be Same:

| Config | Value | Notes |
|--------|-------|-------|
| `database.hostname` | `mysql` | Can be same MySQL instance |
| `database.user` | `tokenuser` | Can share credentials |
| `table.include.list` | `tokenise.JNL_ACQ` | Both read same table |
| `TARGET_TOPIC` | `jnl_acq` | Both write to same topic |

## Record Duplication

**Important:** If both connectors read the SAME MySQL table, Each record will be published TWICE to the topic (once with each key):


**MySQL Insert:**
```sql
INSERT INTO JNL_ACQ (cardNumber, ...) VALUES ('4111111111111111', ...);
```

**Will result in: Kafka Topic (jnl_acq):**

```
MySQL Insert: cardNumber='4111111111111111'
↓
Kafka Topic:
  Message 1: Key="AZ1", Value={cardNumber: "4111111111111111", ...}
  Message 2: Key="AZ2", Value={cardNumber: "4111111111111111", ...}
```

Our Redis sinks filter by key, so each goes to a different Redis database! 

## Example Setup

### Connector 1 Script

```bash
#!/bin/bash

CONNECTOR_NAME="mysql-source-jnl-acq-az1"
CONSTANT_KEY="AZ1"
MYSQL_HOST_ID="184054"
SCHEMA_HISTORY_TOPIC="schema-history-jnl-acq-az1"

# Rest of configuration...
```

### Connector 2 Script

```bash
#!/bin/bash

CONNECTOR_NAME="mysql-source-jnl-acq-az2"
CONSTANT_KEY="AZ2"
MYSQL_HOST_ID="184055"  # DIFFERENT
SCHEMA_HISTORY_TOPIC="schema-history-jnl-acq-az2"  # DIFFERENT

# Rest of configuration...
```

### Create Schema History Topics

```bash
# Topic for AZ1
docker exec broker kafka-topics --bootstrap-server localhost:9092 \
  --create --topic schema-history-jnl-acq-az1 \
  --partitions 1 --replication-factor 1 \
  --config cleanup.policy=delete \
  --config retention.ms=-1

# Topic for AZ2
docker exec broker kafka-topics --bootstrap-server localhost:9092 \
  --create --topic schema-history-jnl-acq-az2 \
  --partitions 1 --replication-factor 1 \
  --config cleanup.policy=delete \
  --config retention.ms=-1
```

### Deploy Both Connectors

```bash
# Deploy connector 1
CONNECTOR_NAME="mysql-source-jnl-acq-az1" \
MYSQL_HOST_ID="184054" \
SCHEMA_HISTORY_TOPIC="schema-history-jnl-acq-az1" \
CONSTANT_KEY="AZ1" \
./jnl_acq_mysql_source-SMT.sh

# Deploy connector 2
CONNECTOR_NAME="mysql-source-jnl-acq-az2" \
MYSQL_HOST_ID="184055" \
SCHEMA_HISTORY_TOPIC="schema-history-jnl-acq-az2" \
CONSTANT_KEY="AZ2" \
./jnl_acq_mysql_source-SMT.sh
```

## Verify Both Connectors Running

```bash
curl http://localhost:8083/connectors | jq
```

**Expected:**
```json
[
  "mysql-source-jnl-acq-az1",
  "mysql-source-jnl-acq-az2"
]
```

## Test Data Flow

```bash
# Insert test record
docker exec mysql mysql -u root -pdbpassword tokenise -e \
  "INSERT INTO JNL_ACQ (acquirerId, cardNumber, tkcardNumber, operationType, transLocalDate, transLocalTime, bankId) \
  VALUES ('DUAL_TEST', '9999888877776666', 'token123', 'PUR', '0214', '120000', 'BANK01');"

# Check Kafka - should see TWO messages (one per connector)
kcat -b localhost:9092 -t jnl_acq -C -f 'Key: %k\n' -o -10 -e
```

**Expected output:**
```
Key: AZ1
Key: AZ2
```

## Redis Sink Behavior

With two source connectors, your Redis sink connectors will behave as:

**Sink 1 (filters for AZ1):**
```bash
KAFKA_KEY_FILTER=AZ1 ./jnl_acq_redis_sink_az1-NO-TTL.sh
```
- Processes only messages with key="AZ1"
- Stores in Redis DB 0

**Sink 2 (filters for AZ2):**
```bash
KAFKA_KEY_FILTER=AZ2 \
REDIS_DATABASE=1 \
CONNECTOR_NAME=redis-sink-jnl-acq-az2 \
./jnl_acq_redis_sink_az1-NO-TTL.sh
```
- Processes only messages with key="AZ2"
- Stores in Redis DB 1

**Result:** Same cardNumber exists in BOTH Redis databases!

```bash
# Check Redis DB 0 (AZ1 data)
docker exec redis redis-cli -n 0 GET '9999888877776666'

# Check Redis DB 1 (AZ2 data)
docker exec redis redis-cli -n 1 GET '9999888877776666'
```

## Common Use Cases

### Use Case 1: Redundancy / Failover
- Same MySQL source
- Two connectors with different keys
- Two Redis databases
- If one fails, the other continues

### Use Case 2: Different MySQL Sources
- MySQL Database 1 (AZ datacenter) → AZ1
- MySQL Database 2 (EU datacenter) → AZ2
- Both write to same Kafka topic
- Filtered into separate Redis databases

### Use Case 3: A/B Testing
- Same source, different keys
- Test different filtering rules
- Compare results in different Redis DBs

## Important MySQL Consideration

**Binlog Position Tracking:**

Each connector tracks its position independently. If you:
1. Stop Connector 1
2. Insert records
3. Start Connector 1

Connector 1 will catch up from where it stopped, while Connector 2 continues normally.

**Offsets are stored per connector** in Kafka Connect's internal topics.

## Troubleshooting

### Connectors Conflict

**Symptom:** One connector fails with "server id already in use"

**Solution:** Ensure each has unique `database.server.id`

### Schema History Topic Errors

**Symptom:** "Compacted topic cannot accept message without key"

**Solution:** Ensure topics use `cleanup.policy=delete`, not `compact`

### Duplicate Data Unexpected

**Symptom:** "Why is each record appearing twice?"

**Answer:** This is expected! Two connectors = two copies of each record.

## Summary

**To run 2 connectors on the SAME MySQL source:**

1. ✅ Different `database.server.id` (184054 vs 184055)
2. ✅ Different `schema.history.internal.kafka.topic`
3. ✅ Different `name`
4. ✅ Different `CONSTANT_KEY` (AZ1 vs AZ2)
5. ✅ Same `TARGET_TOPIC` (both write to jnl_acq)

**Result:** Each record published twice with different keys! 🎯
