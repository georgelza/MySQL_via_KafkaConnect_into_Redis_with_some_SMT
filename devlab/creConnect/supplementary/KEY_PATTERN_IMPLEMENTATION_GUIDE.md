# Redis Key Pattern Feature - Implementation Guide

## Overview

This document describes the new **KEY_PATTERN** feature for your Kafka Connect Redis Sink connector. This feature allows you to add prefixes, suffixes, or custom patterns to Redis keys for better organization, namespacing, and multi-tenant deployments.

---

## What Changed?

### New Files
1. **RedisKeyFormatter.java** - New SMT class that formats Redis keys using configurable patterns

### Modified Files
2. **jnl_acq_redis_sink-SMT-with-pattern.sh** - Updated deployment script with KEY_PATTERN support

---

## Architecture

### Transform Chain (NEW)
```
filterKey          -> Filters by Kafka key (AZ1/AZ2)
addTimestamp       -> Adds createdAt timestamp
selectFields       -> Selects specific fields
extractRedisKey    -> Extracts cardNumber to key
flattenKey         -> Flattens struct key to string
formatRedisKey     -> 🆕 FORMATS KEY WITH PATTERN
removeCardNumber   -> Removes cardNumber from value
valueToJsonString  -> Converts value to JSON string
```

### Redis Key Transformation Flow

**Before (Original):**
```
cardNumber: "4111111111111111"
    ↓
Redis Key: "4111111111111111"
```

**After (With Pattern):**
```
cardNumber: "4111111111111111"
    ↓
Pattern: "az1:card:${key}"
    ↓
Redis Key: "az1:card:4111111111111111"
```

---

## Configuration

### Environment Variables

#### REDIS_KEY_PATTERN
Controls the Redis key format using `${key}` as a placeholder for the original key value.

**Examples:**

| Pattern | Input Key | Redis Key | Use Case |
|---------|-----------|-----------|----------|
| `${key}` | `4111111111111111` | `4111111111111111` | Default (no change) |
| `card:${key}` | `4111111111111111` | `card:4111111111111111` | Simple namespace |
| `az1:card:${key}` | `4111111111111111` | `az1:card:4111111111111111` | Multi-region namespace |
| `${key}:v1` | `4111111111111111` | `4111111111111111:v1` | Versioning |
| `tenant:prod:${key}` | `4111111111111111` | `tenant:prod:4111111111111111` | Multi-tenant |

---

## Deployment Examples

### Example 1: AZ1 with Namespace
```bash
export CONNECTOR_NAME="redis-sink-jnl-acq-az1"
export KAFKA_KEY_FILTER="AZ1"
export REDIS_KEY_PATTERN="az1:card:\${key}"
export REDIS_DATABASE="0"

./jnl_acq_redis_sink-SMT-with-pattern.sh
```

**Result:**
- Kafka Key: `AZ1`
- Card Number: `4111111111111111`
- Redis Key: `az1:card:4111111111111111`
- Redis Value: `{"acqJnlSeqNumber":12345,"tkcardNumber":"...","createdAt":"..."}`

### Example 2: AZ2 with Namespace
```bash
export CONNECTOR_NAME="redis-sink-jnl-acq-az2"
export KAFKA_KEY_FILTER="AZ2"
export REDIS_KEY_PATTERN="az2:card:\${key}"
export REDIS_DATABASE="1"

./jnl_acq_redis_sink-SMT-with-pattern.sh
```

**Result:**
- Kafka Key: `AZ2`
- Card Number: `5555666677778888`
- Redis Key: `az2:card:5555666677778888`

### Example 3: No Pattern (Backward Compatible)
```bash
export CONNECTOR_NAME="redis-sink-jnl-acq-simple"
export REDIS_KEY_PATTERN="\${key}"  # Or omit this line entirely

./jnl_acq_redis_sink-SMT-with-pattern.sh
```

**Result:**
- Redis Key: `4111111111111111` (original behavior)

---

## Benefits

### 1. **Namespace Isolation**
```
az1:card:4111111111111111
az2:card:4111111111111111
```
- Separate data by region/availability zone
- Avoid key collisions between environments

### 2. **Easy Pattern Matching**
```bash
# Get all AZ1 cards
redis-cli KEYS 'az1:card:*'

# Get all AZ2 cards
redis-cli KEYS 'az2:card:*'

# Count AZ1 cards
redis-cli --scan --pattern 'az1:card:*' | wc -l
```

### 3. **Versioning Support**
```
card:4111111111111111:v1
card:4111111111111111:v2
```
- Support schema migrations
- A/B testing different data formats

### 4. **Multi-Tenant Deployment**
```
tenant:alpha:4111111111111111
tenant:beta:4111111111111111
```
- Share Redis instance across tenants
- Isolate data per tenant

---

## Testing

### 1. Verify Pattern is Applied

```bash
# Insert test data
docker exec mysql mysql -u root -pdbpassword tokenise -e \
  "INSERT INTO JNL_ACQ (acquirerId, cardNumber, tkcardNumber, operationType, transLocalDate, transLocalTime, bankId) \
   VALUES ('TEST', '9999888877776666', 'Test offer', 'PUR', '0214', '123456', 'BANK01');"

# Check Redis (with pattern)
docker exec redis redis-cli -n 0 GET 'az1:card:9999888877776666'

# Expected output:
{"acqJnlSeqNumber":12345,"tkcardNumber":"Test offer","createdAt":"2026-02-14T12:34:56.789Z"}
```

### 2. Pattern Search

```bash
# List all keys with pattern
docker exec redis redis-cli -n 0 KEYS 'az1:card:*'

# Count keys
docker exec redis redis-cli -n 0 --scan --pattern 'az1:card:*' | wc -l
```

### 3. Compare AZ1 vs AZ2

```bash
# AZ1 keys
docker exec redis redis-cli -n 0 KEYS 'az1:card:*' | head -5

# AZ2 keys
docker exec redis redis-cli -n 1 KEYS 'az2:card:*' | head -5
```

---

## Migration Strategy

### Scenario: Adding Patterns to Existing Deployment

If you already have keys in Redis without patterns (e.g., `4111111111111111`), and you want to add patterns (e.g., `az1:card:4111111111111111`):

#### Option 1: Fresh Start (Recommended)
1. Flush Redis database: `redis-cli FLUSHDB`
2. Deploy new connector with pattern
3. Data will repopulate with new key format

#### Option 2: Dual-Write Period
1. Keep old connector running
2. Deploy new connector with pattern to different Redis DB
3. Migrate applications to use new keys
4. Decommission old connector

#### Option 3: Redis Key Migration Script
```bash
#!/bin/bash
# Migrate keys from old format to new format

OLD_PATTERN="*"
NEW_PREFIX="az1:card:"

redis-cli KEYS "$OLD_PATTERN" | while read key; do
    # Skip if already has prefix
    if [[ $key == $NEW_PREFIX* ]]; then
        continue
    fi
    
    # Get value
    value=$(redis-cli GET "$key")
    
    # Create new key
    new_key="${NEW_PREFIX}${key}"
    
    # Set new key
    redis-cli SET "$new_key" "$value"
    
    # Optional: Delete old key after verification
    # redis-cli DEL "$key"
    
    echo "Migrated: $key -> $new_key"
done
```

---

## Troubleshooting

### Problem: Keys Don't Have Pattern

**Check:**
```bash
# View connector config
curl http://localhost:8083/connectors/redis-sink-jnl-acq-az1/config | jq

# Look for:
"transforms.formatRedisKey.key.pattern": "az1:card:${key}"
```

**Solution:**
- Verify `REDIS_KEY_PATTERN` environment variable is set
- Check shell escaping: `\${key}` (escaped) vs `${key}` (shell variable)
- Restart connector after config change

### Problem: Pattern Not Applied to All Keys

**Check:**
```bash
# List all keys
docker exec redis redis-cli KEYS '*'

# Count by pattern
docker exec redis redis-cli KEYS 'az1:card:*' | wc -l
docker exec redis redis-cli KEYS '*' | wc -l
```

**Solution:**
- Old data may exist without pattern (see Migration Strategy above)
- Verify transform order in connector config
- Check connector logs for errors

### Problem: Can't Find Keys with Pattern

**Check:**
```bash
# Make sure you're using correct pattern in queries
docker exec redis redis-cli KEYS 'az1:card:*'  # Correct
docker exec redis redis-cli GET 'az1:card:4111111111111111'  # Correct

# NOT this:
docker exec redis redis-cli GET '4111111111111111'  # Wrong - old format
```

---

## Advanced Configuration

### Custom Transform in Connector Config

If you prefer to configure the transform directly in the connector JSON (instead of using the shell script):

```json
{
  "name": "redis-sink-custom",
  "config": {
    ...
    "transforms": "filterKey,addTimestamp,selectFields,extractRedisKey,flattenKey,formatRedisKey,removeCardNumber,valueToJsonString",
    
    "transforms.formatRedisKey.type": "com.token.kafka.connect.transforms.RedisKeyFormatter",
    "transforms.formatRedisKey.key.pattern": "az1:card:${key}",
    "transforms.formatRedisKey.key.pattern.null.handling": "pass"
  }
}
```

### Null Key Handling

Control what happens when a key is null:

```bash
# Pass through null keys (default)
"transforms.formatRedisKey.key.pattern.null.handling": "pass"

# Drop records with null keys
"transforms.formatRedisKey.key.pattern.null.handling": "drop"
```

---

## Performance Considerations

### Pattern Complexity
- Simple patterns (e.g., `az1:card:${key}`) have negligible performance impact
- String replacement is O(n) where n = pattern length
- Typical overhead: <1ms per record

### Redis Key Size
- Longer keys use more memory
- `az1:card:4111111111111111` (26 bytes) vs `4111111111111111` (16 bytes)
- For 1M keys: ~10MB additional memory usage

### Pattern Search Performance
```bash
# O(N) - scans all keys
redis-cli KEYS 'az1:card:*'

# Better for production (non-blocking)
redis-cli --scan --pattern 'az1:card:*'
```

---

## Summary

✅ **What You Get:**
- Flexible key formatting with patterns
- Namespace isolation (az1, az2)
- Easy pattern-based queries
- Backward compatible (default: `${key}`)

✅ **How to Use:**
1. Add `RedisKeyFormatter.java` to your SMT project
2. Compile and deploy SMT JAR to Kafka Connect
3. Use updated shell script or configure transform manually
4. Set `REDIS_KEY_PATTERN` environment variable

✅ **Recommended Patterns:**
- Multi-region: `az1:card:${key}`, `az2:card:${key}`
- Versioned: `card:${key}:v1`
- Tenant: `tenant:alpha:${key}`
- Default: `${key}` (no change)

---

## Next Steps

1. **Compile the SMT:**
   ```bash
   cd kafka-connect-smt
   mvn clean package
   cp target/kafka-connect-smt-1.0.jar $KAFKA_CONNECT_PLUGIN_PATH
   ```

2. **Restart Kafka Connect:**
   ```bash
   docker-compose restart kafka-connect
   ```

3. **Deploy Connectors:**
   ```bash
   export REDIS_KEY_PATTERN="az1:card:\${key}"
   ./jnl_acq_redis_sink-SMT-with-pattern.sh
   ```

4. **Test:**
   ```bash
   # Insert test data
   docker exec mysql mysql -u root -pdbpassword tokenise -e \
     "INSERT INTO JNL_ACQ ..."
   
   # Verify in Redis
   docker exec redis redis-cli GET 'az1:card:9999888877776666'
   ```

---

**Questions? Issues?**
- Check connector status: `curl http://localhost:8083/connectors/redis-sink-jnl-acq-az1/status`
- View connector config: `curl http://localhost:8083/connectors/redis-sink-jnl-acq-az1/config`
- Check logs: `docker logs kafka-connect`
