# Redis Sink with createdAt Timestamp

## Changes Made


## Project Structure

```
kafka-custom-smt/
├── pom.xml
└── src/main/java/com/token/kafka/connect/transforms/
    ├── FilterAndExtractKey.java 
    ├── FilterByKafkaKey.java      
    ├── ValueToJsonString.java    
    └── AddTimestamp.java          
```


**Features:**
- ISO8601 format: `"2026-02-14T10:30:45.123Z"`
- Configurable timezone (default: Africa/Johannesburg)
- Or epoch milliseconds if preferred

## Deployment


### Step 1: Build

```bash
mvn clean package
```

### Step 2: Deploy

```bash
docker cp target/kafka-connect-token-smt-1.0.0.jar connect:/usr/share/java/kafka/
# - or
# volumes mount via docker/docker compose: 
# target/kafka-connect-token-smt-1.0.0.jar -> /usr/share/java/kafka/kafka-connect-token-smt-1.0.0.jar

docker restart connect
sleep 15
```

### Step 3: Verify SMT Loaded

```bash
docker logs connect 2>&1 | grep AddTimestamp
```

**Expected:**
```
Added plugin 'com.token.kafka.connect.transforms.AddTimestamp'
```

### Step 4: Create Connector

```bash
# Delete old connector
curl -X DELETE http://localhost:8083/connectors/redis-sink-jnl-acq-az1

# Create new connector with timestamp
KAFKA_KEY_FILTER=AZ1 ./jnl_acq_redis_sink.sh
```

## Transform Chain

```json
"transforms": "filterKey,addTimestamp,selectFields,extractRedisKey,flattenKey,removeCardNumber,valueToJsonString"
```

**Order matters:**

1. **filterKey** - Keep only Kafka key = "AZ1"
2. **addTimestamp** - Add `createdAt` field (ISO8601)
3. **selectFields** - Keep `acqJnlSeqNumber`, `tkcardNumber`, `cardNumber`, `createdAt`
4. **extractRedisKey** - Use `cardNumber` as message key
5. **flattenKey** - Extract plain string from key
6. **removeCardNumber** - Remove `cardNumber` from value (it's the key!)
7. **valueToJsonString** - Convert to JSON string

## Redis Data Structure

**Key:** `"4111111111111111"` (cardNumber value)

**Value:**
```json
{
  "acqJnlSeqNumber": 12345,
  "tkcardNumber": "Special offer",
  "createdAt": "2026-02-14T10:30:45.123Z"
}
```

**Note:** `cardNumber` is NOT in the value (it's the key)

## Test

```bash
# Insert test data
docker exec mysql mysql -u root -pdbpassword tokenise -e \
  "INSERT INTO JNL_ACQ (acquirerId, cardNumber, tkcardNumber, operationType, transLocalDate, transLocalTime, bankId) \
  VALUES ('TEST', '9999888877776666', 'Test with timestamp', 'PUR', '0214', '120000', 'BANK01');"

# Wait for processing
sleep 10

# Check Redis
docker exec redis redis-cli -n 0 GET '9999888877776666'
```

**Expected output:**
```json
{"acqJnlSeqNumber":12345,"tkcardNumber":"Test with timestamp","createdAt":"2026-02-14T10:30:45.123Z"}
```

## Timestamp Formats

### ISO8601 (Default - Recommended)
```json
"createdAt": "2026-02-14T10:30:45.123Z"
```

**Configuration:**
```json
"transforms.addTimestamp.timestamp.format": "iso8601",
"transforms.addTimestamp.timestamp.timezone": "Africa/Johannesburg"
```

### Epoch Milliseconds (Alternative)
```json
"createdAt": 1739527845123
```

**Configuration:**
```json
"transforms.addTimestamp.timestamp.format": "epoch"
```

## Timezones

**Common options:**
- `UTC` - Coordinated Universal Time
- `Africa/Johannesburg` - South Africa Time (SAST)
- `America/New_York` - Eastern Time
- `Europe/London` - British Time

**Current script uses:** `Africa/Johannesburg`

## Verify Timestamp Accuracy

```bash
# Insert record
docker exec mysql mysql -u root -pdbpassword tokenise -e \
  "INSERT INTO JNL_ACQ (acquirerId, cardNumber, tkcardNumber, operationType, transLocalDate, transLocalTime, bankId) \
  VALUES ('TIME_TEST', '1111222233334444', 'Timestamp test', 'PUR', '0214', '120000', 'BANK01');"

# Get current time
date -u +"%Y-%m-%dT%H:%M"

# Check Redis (within seconds)
docker exec redis redis-cli -n 0 GET '1111222233334444' | jq '.createdAt'
```

The timestamps should match within a few seconds!

## Benefits

✅ **Track when record was created** in Redis  
✅ **cardNumber not duplicated** (it's the key)  
✅ **Clean value structure**  
✅ **ISO8601 standard format** (easy to parse everywhere)  
✅ **Timezone aware** (configurable)  

## Summary

**4 SMT files:**
1. FilterAndExtractKey.java
2. FilterByKafkaKey.java
3. ValueToJsonString.java
4. AddTimestamp.java

**Redis structure:**
- Key: cardNumber
- Value: {acqJnlSeqNumber, tkcardNumber, createdAt}
