# Custom SMT: Filter and Extract Clean Key

## Overview

This is our MySQL Source side, consuming records from our MySQL Datastores / JNL_ACQ table.

This custom SMT does TWO things:

- **Filters messages**: Only publishes messages where `cardNumber` AND `discountDesc` are populated (non-null and non-empty)

- **Clean key**: Extracts just `"AZ1"` as a plain string key

## Build Instructions

### Step 1: Create Project Structure

```
kafka-custom-smt/
├── pom.xml
└── src/main/java/com/token/kafka/connect/transforms/
    ├── FilterAndExtractKey.java 
    ├── FilterByKafkaKey.java      
    ├── ValueToJsonString.java    
    └── AddTimestamp.java          
```

### Step 2: Create pom.xml

Create `pom.xml` in the project root:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <groupId>com.token</groupId>
    <artifactId>kafka-connect-filter-smt</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>
    
    <name>Kafka Connect Filter and Extract Key SMT</name>
    
    <properties>
        <maven.compiler.source>11</maven.compiler.source>
        <maven.compiler.target>11</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <kafka.version>3.6.0</kafka.version>
    </properties>
    
    <dependencies>
        <dependency>
            <groupId>org.apache.kafka</groupId>
            <artifactId>connect-api</artifactId>
            <version>${kafka.version}</version>
            <scope>provided</scope>
        </dependency>
        <dependency>
            <groupId>org.apache.kafka</groupId>
            <artifactId>connect-transforms</artifactId>
            <version>${kafka.version}</version>
            <scope>provided</scope>
        </dependency>
    </dependencies>
    
    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.11.0</version>
                <configuration>
                    <source>11</source>
                    <target>11</target>
                </configuration>
            </plugin>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-jar-plugin</artifactId>
                <version>3.3.0</version>
            </plugin>
        </plugins>
    </build>
</project>
```

### Step 3: Build the JAR

```bash
# Make sure you have Maven installed
mvn --version

# Build the project
mvn clean package

# The JAR will be in: target/kafka-connect-token-smt-1.0.0.jar
```

### Step 4: Deploy to Kafka Connect

```bash
# Copy JAR to Kafka Connect container
docker cp target/kafka-connect-token-smt-1.0.0.jar connect:/usr/share/java/kafka/
# - or
# volumes mount via docker/docker compose: 
# target/kafka-connect-token-smt-1.0.0.jar -> /usr/share/java/kafka/kafka-connect-token-smt-1.0.0.jar

# Restart Kafka Connect to load the new plugin
docker restart connect

# Wait for it to start
sleep 15

# Verify the plugin is loaded
curl http://localhost:8083/connector-plugins | jq '.[] | select(.class | contains("FilterAndExtractKey"))'
```

## Connector Configuration

### Step 4: Deploy to Kafka Connect

Once deployed, update your connector configuration in below file and execute creConnect/jnl_acq_mysql_source_az1-SMT.sh

```json
{
  "name": "mysql-source-jnl-acq-az1",
  "config": {
    "connector.class": "io.debezium.connector.mysql.MySqlConnector",
    "tasks.max": "1",
    "database.hostname": "mysql",
    "database.port": "3306",
    "database.user": "tokenuser",
    "database.password": "tokenpw",
    "database.server.id": "184054",
    "topic.prefix": "mysql",
    "database.include.list": "tokenise",
    "table.include.list": "tokenise.JNL_ACQ",
    "include.schema.changes": "false",
    "database.connectionTimeZone": "Africa/Johannesburg",
    "schema.history.internal.kafka.bootstrap.servers": "broker:29092",
    "schema.history.internal.kafka.topic": "schema-history-jnl-acq",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "false",
    "transforms": "route,unwrap,addKeyField,extractKey,filterAndKey,removeKeyField",
    "transforms.route.type": "io.debezium.transforms.ByLogicalTableRouter",
    "transforms.route.topic.regex": "mysql.tokenise.JNL_ACQ",
    "transforms.route.topic.replacement": "jnl_acq",
    "transforms.unwrap.type": "io.debezium.transforms.ExtractNewRecordState",
    "transforms.unwrap.drop.tombstones": "false",
    "transforms.unwrap.delete.handling.mode": "rewrite",
    "transforms.addKeyField.type": "org.apache.kafka.connect.transforms.InsertField\$Value",
    "transforms.addKeyField.static.field": "key",
    "transforms.addKeyField.static.value": "AZ1",
    "transforms.extractKey.type": "org.apache.kafka.connect.transforms.ValueToKey",
    "transforms.extractKey.fields": "key",
    "transforms.filterAndKey.type": "com.token.kafka.connect.transforms.FilterAndExtractKey",
    "transforms.filterAndKey.key.field": "key",
    "transforms.filterAndKey.filter.fields": "cardNumber,discountDesc",
    "transforms.filterAndKey.filter.mode": "all",
    "transforms.removeKeyField.type": "org.apache.kafka.connect.transforms.ReplaceField\$Value",
    "transforms.removeKeyField.exclude": "key"
  }
}
```

### Step 4: Create Connector

```bash
# Delete old connector
curl -X DELETE http://localhost:8083/connectors/mysql-source-jnl-acq-az1

# Create new connector with timestamp
CONSTANT_KEY=AZ1 ./jnl_acq_mysql_source-SMT.sh
```

## How It Works

### Transform Chain Order (Important!)

1. **route** - Routes to correct topic
2. **unwrap** - Extracts record from CDC envelope
3. **addKeyField** - Adds `key: "AZ1"` to value
4. **extractKey** - Makes `key` field the message key (creates Struct)
5. **filterAndKey** - FILTERS records AND extracts plain string "AZ1" from Struct key
6. **removeKeyField** - Removes `key` field from value

### Advantages

✅ Only relevant messages published (saves storage/bandwidth)  
✅ Clean string key `"AZ1"` - no JSON parsing needed  
✅ Configurable filter fields and mode  
✅ Reusable for other connectors  
✅ Production-ready code with proper error handling  

### Configuration Options

| Property | Default | Description |
|----------|---------|-------------|
| `key.field` | `"key"` | Field name in key struct to extract |
| `filter.fields` | `null` | Comma-separated field names to check (e.g., `"cardNumber,discountDesc"`) |
| `filter.mode` | `"all"` | `"all"` (all fields must be populated) or `"any"` (at least one) |

### Filtering Logic

The SMT checks the VALUE for these fields:
- `cardNumber` - Must be non-null and non-empty

- `discountDesc` - Must be non-null and non-empty

**Mode: "all"** (default):

- BOTH fields must be populated

- If either is null or empty → message is DROPPED

**Mode: "any"**:

- AT LEAST ONE field must be populated

- If both are null/empty → message is DROPPED


## Testing

### Insert a record WITH cardNumber and discountDesc (WILL be published)

```bash
docker exec mysql mysql -u root -pdbpassword tokenise -e \
  "INSERT INTO JNL_ACQ (acquirerId, cardNumber, discountDesc, operationType, transLocalDate, transLocalTime, bankId) \
  VALUES ('TEST001', '4111111111111111', 'Some discount', 'PUR', '0213', '120000', 'BANK01');"
```

### Insert a record WITHOUT discountDesc (WILL be filtered out)

```bash
docker exec mysql mysql -u root -pdbpassword tokenise -e \
  "INSERT INTO JNL_ACQ (acquirerId, cardNumber, operationType, transLocalDate, transLocalTime, bankId) \
  VALUES ('TEST002', '4111111111111111', 'PUR', '0213', '120001', 'BANK01');"
```

## Regarding kcat

Install with brew install kcat on MAC.
Execute as per below

### (only messages with BOTH fields populated)

```bash
kcat -b localhost:9092 -t jnl_acq -C -f 'Key: %k\n' -c 10

kcat -b localhost:9092 -t jnl_acq -C -f '%k\n' -c 10

kcat -b localhost:9092 -t jnl_acq -C -f 'Key: %k\n' 
```

**Should output:**

AZ1
AZ1
AZ1
..

### Random Check using kcat

```bash
kcat -b localhost:9092 -t jnl_acq -C -o end -f 'Key: %k | Timestamp: %T\nValue: %s\n\n'

kcat -b localhost:9092 -t jnl_acq -C -f 'Key: %k\n%s\n' -c 1 | tail -n +2 | jq .
```


