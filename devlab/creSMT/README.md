## Java based Single Message Transform package

Simple, this is a java based packaged used by our source and sink connectors to get what we want.

### Building Package

To build the pakcage change into the kafka-custom-smt directory and execute `mvn package clean`

### Deploying Package

Take note, in the `devlab/docker-compose.yaml`, for the connect service we have a volumes mount definition which mout the produced artifact into the container image.

Which then makes it available for the connector scripts as per `<Project Root>/devlab/creConnect` to be used.


## Prerequisites

### 1. SMT Structure - JAR

```bash
src/main/java/com/example/kafka/connect/transforms/
├── FilterAndExtractKey.java  (existing)
    ├── FilterAndExtractKey.java 
    ├── ValueToJsonString.java    
    ├── AddTimestamp.java     
    ├── RedisKeyFormatter.java
    └── FilterByKafkaKey.java 
```