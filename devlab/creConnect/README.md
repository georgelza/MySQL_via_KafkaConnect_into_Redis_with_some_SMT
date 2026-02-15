
## Our Connector Framework

This directory contain the various scripts to deploy our MySQL Kafka Source connectors and the REDIS kafka Sink Connector.

- `jnl_acq_mysql_source-SMT.sh` as documented in `Source_MySQL_SMT_GUIDE.md` for more regarding our Source Connector and deployment.

- `jnl_acq_redis_sink-SMT.sh` as documented in `Sink_REDIS_SMT_GUIDE.md` for more regarding our Sink onnector and deployment.

- Supplementary reading `supplementary/KEY_PATTERN_IMPLEMENTATION_GUIDE.md` and `supplementary/BEFORE_AFTER_COMPARISON.md` for background information regarding the key pattern functionality added on the REDIS Key structure created.

- `deploy-az1-with-pattern.sh` and `deploy-az2-with-pattern.sh` are helper scripts to impliment the supplementary/Key Pattern capability.
   
Both these are dependant on the Java based [**Single Message Transform (SMT)**](https://docs.confluent.io/kafka-connectors/transforms/current/overview.html) packages as defined in `<Project root>/devlab/creSMT` directory.

See `<Project root>/devlab/creSMT/README.md` for building our SMT function used by the `jnl_acq_mysql_source-SMT.sh` and `jnl_acq_redis_sink-SMT.sh` connector definitions/tasks.

### jnl_acq_mysql_source-SMT.sh

This is our primary Kafka Source Connector to ingest records from our MySQL Datastore.

See: [debezium-connector-mysql](https://debezium.io/docs/connectors/mysql/)

It will: 

1. Source records from our MySQL `tokenise.JNL_ACQ` table using Kafka Connect Debezium MySQL Source Connector
2. filter out records that have both the cardNumber and tkcardNumber pupulated
   1. By doing this filter here we reduce the number of records published onto our Kafka Topic and the associated workload/data retention/costs.
3. Assign a user specified value for the message key
4. Publish output onto specified topic: `jnl_acq`

### jnl_acq_redis_sink-SMT.sh

This is our primary Kafka Connect Sink Connector to sink records into our REDIS Datastore.

See: [jcustenborder/kafka-connect-redis](https://docs.confluent.io/kafka-connectors/redis/current/overview.html)

It will:

1. Source records from our `jnl_acq` topic, 
2. Filter our records based on message key
3. select specific columns, constructing output JSON Payload
4. Add to payload createdAt field with system time stamp
5. Sink into our `REDIS datastore` using the above Kafka Connect REDIS Sink Connector

### jnl_acq_mysql_source-FULL.sh

Similar to our First Source connector, but this example consume/ingest all records from our MySQL tokenise.JNL_ACQ table, no filtering.
   
See: [debezium-connector-mysql](https://debezium.io/docs/connectors/mysql/)

It will:

1. Source records from our MySQL tokenise.JNL_ACQ table using Kafka Connect Debezium MySQL Source Connector
2. Assign a user specified value for the message key 
3. Publish records onto onto our topic: `jnl_acq`
4. For the REDIS sink, Filter based on the key assigned
5. Extract subset of columns
6. Build a custom K/V store key
7. Sink K/V set to REDIS
