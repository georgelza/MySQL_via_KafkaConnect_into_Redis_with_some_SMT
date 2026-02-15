# Custom SMT: Redis Sink Connector Guide

## Overview

This is our REDIS Sink side, consuming records from our Kafka Topic `jnl_acq` and building a K/V record and sinking into our REDIS in memory Datastores.


- **Filtering**: Only processes messages with specified Kafka key (e.g., `AZ1` or `AZ2`)

- **Selective fields**: Only stores `acqJnlSeqNumber` and `tkcardNumber`

- **Redis structure**: 

  - Key: `cardNumber` value
  - Value: JSON string with selected fields

## Architecture

```
Kafka Topic: jnl_acq
├── Messages with key="AZ1" → Redis Sink Connector 1 → Redis DB 0
└── Messages with key="AZ2" → Redis Sink Connector 2 → Redis DB 1
```

## Build Instructions

## Prerequisites

### 1. Add FilterByKafkaKey SMT to your JAR

Update `pom.xml` dependencies and add `FilterByKafkaKey.java` to your project:

```
src/main/java/com/example/kafka/connect/transforms/
├── FilterAndExtractKey.java  (existing)
    ├── FilterAndExtractKey.java 
    ├── ValueToJsonString.java    
    ├── AddTimestamp.java     
    ├── RedisKeyFormatter.java
    └── FilterByKafkaKey.java 
```

### 2. Rebuild and Deploy

```bash
cd kafka-custom-smt
mvn clean package
docker cp target/kafka-connect-filter-smt-1.0.0.jar connect:/usr/share/java/kafka/kafka-connect-token-smt-1.0.0.jar
# - or
# volumes mount via docker/docker compose: 
# target/kafka-connect-token-smt-1.0.0.jar -> /usr/share/java/kafka/kafka-connect-token-smt-1.0.0.jar

docker restart connect
sleep 15
```

### 3. Verify SMT is Loaded

```bash
docker logs connect 2>&1 | grep -i "FilterByKafkaKey"
```

Expected:
```
Added plugin 'com.example.kafka.connect.transforms.FilterByKafkaKey'
```

## Create Connectors

### Connector 1: AZ1 → Redis DB 0

```bash
KAFKA_KEY_FILTER=AZ1 \
REDIS_DATABASE=0 \
CONNECTOR_NAME=redis-sink-jnl-acq-az1 \
./jnl_acq_redis_sink-SMT.sh
```

### Connector 2: AZ2 → Redis DB 1

```bash
KAFKA_KEY_FILTER=AZ2 \
REDIS_DATABASE=1 \
CONNECTOR_NAME=redis-sink-jnl-acq-az2 \
./jnl_acq_redis_sink-SMT.sh
```

## Redis Data Structure

### Key Format
The `cardNumber` field value becomes the Redis key:
```
4111111111111111
```

### Value Format

JSON string with selected fields:

```json
{
  "acqJnlSeqNumber": 12345,
  "tkcardNumber":   "10% discount"
}
```

## Configuration Options

| Variable | Default | Description |
|----------|---------|-------------|
| `SOURCE_TOPIC` | `jnl_acq` | Kafka topic to consume from |
| `KAFKA_KEY_FILTER` | `AZ1` | Filter by this Kafka message key |
| `REDIS_HOST` | `redis` | Redis hostname |
| `REDIS_PORT` | `6379` | Redis port |
| `REDIS_DATABASE` | `0` | Redis database number (0-15) |
| `REDIS_PASSWORD` | (empty) | Redis password if authentication enabled |
| `REDIS_KEY_FIELD` | `cardNumber` | Field to use as Redis key |
| `REDIS_VALUE_FIELDS` | `acqJnlSeqNumber,tkcardNumber` | Comma-separated fields for Redis value |

## Testing

### 1. Insert Test Data

**Test data for AZ1:**
```bash
docker exec mysql mysql -u root -pdbpassword tokenise -e \
  "INSERT INTO JNL_ACQ (acquirerId, cardNumber, tkcardNumber, operationType, transLocalDate, transLocalTime, bankId) \
  VALUES ('TEST_AZ1', '4111111111111111', '4222222222222222, 'PUR', '0214', '120000', 'BANK01');"
```

**Test data for AZ2:**
```bash
docker exec mysql mysql -u root -pdbpassword tokenise -e \
  "INSERT INTO JNL_ACQ (acquirerId, cardNumber, tkcardNumber, operationType, transLocalDate, transLocalTime, bankId) \
  VALUES ('TEST_AZ2', '5555555555555555', '5222222222222222', 'PUR', '0214', '120000', 'BANK02');"
```

### 2. Verify in Redis

**Check DB 0 (AZ1 data):**
```bash
docker exec redis redis-cli -n 0 KEYS '*'
docker exec redis redis-cli -n 0 GET '4111111111111111'
```

Expected:
```
{"acqJnlSeqNumber":12345,"tkcardNumber":"AZ1 discount"}
```

**Check DB 1 (AZ2 data):**
```bash
docker exec redis redis-cli -n 1 KEYS '*'
docker exec redis redis-cli -n 1 GET '5555555555555555'
```

Expected:
```json
{
  "acqJnlSeqNumber":12346,
  "tkcardNumber":"AZ2 discount"
}
```

### 3. Monitor Data Flow

**Check Kafka topic:**
```bash
kcat -b localhost:9092 -t jnl_acq -C -f 'Key: %k | cardNumber: ' -o -10
```

**Check Redis population:**
```bash
# Total keys in DB 0
docker exec redis redis-cli -n 0 DBSIZE

# Total keys in DB 1
docker exec redis redis-cli -n 1 DBSIZE

# View random keys
docker exec redis redis-cli -n 0 RANDOMKEY
docker exec redis redis-cli -n 0 GET $(docker exec redis redis-cli -n 0 RANDOMKEY)
```

## Transform Chain Explanation

The connector uses this transform chain:

```json
"transforms": "filterKey,selectFields,extractRedisKey"
```

1. **filterKey**: 
   - Type:  `FilterByKafkaKey`
   - Action: Drops messages where Kafka key ≠ specified value
   - Config: `key.value = "AZ1"`

2. **selectFields**: 
   - Type:  `ReplaceField$Value`
   - Action: Keeps only specified fields (plus cardNumber for next step)
   - Config: `include = "acqJnlSeqNumber,tkcardNumber,cardNumber"`

3. **extractRedisKey**: 
   - Type:  `ValueToKey`
   - Action: Uses `cardNumber` field as the message key (becomes Redis key)
   - Config:`fields = "cardNumber"`

## Troubleshooting

### Connector fails with "FilterByKafkaKey not found"

**Solution**: Rebuild JAR with both SMTs and redeploy:
```bash
# Make sure FilterByKafkaKey.java is in the project
ls src/main/java/com/example/kafka/connect/transforms/FilterByKafkaKey.java

# Rebuild
mvn clean package

# Redeploy
docker cp target/kafka-connect-filter-smt-1.0.0.jar connect:/usr/share/java/kafka/
docker restart connect
```

### No data appears in Redis

**Check connector status:**
```bash
curl http://localhost:8083/connectors/redis-sink-jnl-acq-az1/status | jq
```

**Check if messages are on topic:**
```bash
kcat -b localhost:9092 -t jnl_acq -C -f 'Key: %k\n' -c 10
```

**Check connector logs:**
```bash
docker logs connect 2>&1 | grep -i redis | tail -50
```

### Wrong data in Redis

**Check Redis directly:**
```bash
# Connect to Redis CLI
docker exec -it redis redis-cli -n 0

# List all keys
KEYS *

# Get a specific key
GET "4111111111111111"

# See key type
TYPE "4111111111111111"

# Delete all keys in current DB (CAREFUL!)
FLUSHDB
```

## Advanced: Different Fields Per Key

To store different fields for AZ1 vs AZ2:

**AZ1 Connector** (stores acqJnlSeqNumber, tkcardNumber):
```bash
KAFKA_KEY_FILTER=AZ1 \
REDIS_VALUE_FIELDS="acqJnlSeqNumber,tkcardNumber" \
./create-redis-sink-with-filter.sh
```

**AZ2 Connector** (stores different fields):
```bash
KAFKA_KEY_FILTER=AZ2 \
REDIS_VALUE_FIELDS="acqJnlSeqNumber,bankId,transDateTime" \
CONNECTOR_NAME=redis-sink-jnl-acq-az2 \
REDIS_DATABASE=1 \
./create-redis-sink-with-filter.sh
```

## Production Considerations

1. **Redis Persistence**: Configure Redis RDB or AOF persistence
2. **Key Expiration**: Add TTL to Redis keys if needed
3. **Duplicate Keys**: `cardNumber` must be unique, or use composite key
4. **Error Handling**: Configure `errors.tolerance` and DLQ
5. **Scaling**: Increase `tasks.max` for higher throughput
6. **Monitoring**: Track Redis memory usage and connector lag

## Summary

✅ Filter by Kafka message key (AZ1, AZ2)  
✅ Extract only needed fields  
✅ Use cardNumber as Redis key  
✅ Store JSON value in Redis  
✅ Separate databases for different sources  
✅ Production-ready configuration  
