/* //////////////////////////////////////////////////////////////////////////////////////////////////////
*
*       Project         :   Kafka Connect Source/Sink Connector SMT Function
*
*       File            :   FilterByKafkaKey.java
*
*       Description     :   Kafka Connect Source/Sink Connector SMT Function
*
*       Created     	:   Feb 2026
*
*       copyright       :   Copyright 2026, - G Leonard, georgelza@gmail.com
*
*       GIT Repo        :   https://github.com/georgelza/MySQL_via_KafkaConnect_into_Redis_with_some_SMT.git
*
*       Blog            :
*
*       Custom SMT that:
* 
*       Sink Engine:
* 
*       Custom SMT to filter records by Kafka message key.
*       Only passes through records where the key matches the specified value.
* 
*       Configuration:
* 
*       - key.value: The key value to match (e.g., "AZ1", "AZ2")
* 
*       Usage:
* 
*           "predicates":                            "filterByKafkaKey",
*           "predicates.filterByKafkaKey.type":      "com.token.kafka.connect.transforms.FilterByKafkaKey",
*           "predicates.filterByKafkaKey.key.value": "AZ1"
* 
*       Or as a transform that returns null for filtered records:
* 
*           "transforms": "filterKey",
*           "transforms.filterKey.type": "com.token.kafka.connect.transforms.FilterByKafkaKey",
*           "transforms.filterKey.key.value": "AZ1"
* 
*///////////////////////////////////////////////////////////////////////////////////////////////////////

package com.token.kafka.connect.transforms;

import org.apache.kafka.common.config.ConfigDef;
import org.apache.kafka.connect.connector.ConnectRecord;
import org.apache.kafka.connect.transforms.Transformation;
import org.apache.kafka.connect.transforms.util.SimpleConfig;

import java.util.Map;

public class FilterByKafkaKey<R extends ConnectRecord<R>> implements Transformation<R> {
    
    private static final String KEY_VALUE_CONFIG = "key.value";
    
    private String keyValue;
    
    @Override
    public void configure(Map<String, ?> configs) {
        SimpleConfig config = new SimpleConfig(config(), configs);
        keyValue = config.getString(KEY_VALUE_CONFIG);
    }
    
    @Override
    public R apply(R record) {
        if (record == null) {
            return null;
        }
        
        Object key = record.key();
        
        // If no filter configured, pass everything through
        if (keyValue == null || keyValue.trim().isEmpty()) {
            return record;
        }
        
        // If key matches, pass through; otherwise return null (drop record)
        if (key != null && keyValue.equals(key.toString())) {
            return record;
        }
        
        // Key doesn't match - drop the record
        return null;
    }
    
    @Override
    public ConfigDef config() {
        return new ConfigDef()
            .define(KEY_VALUE_CONFIG, 
                    ConfigDef.Type.STRING, 
                    null, 
                    ConfigDef.Importance.HIGH, 
                    "Kafka message key value to match (e.g., 'AZ1', 'AZ2'). Only records with this key will pass through.");
    }
    
    @Override
    public void close() {
        // No resources to close
    }
}
