package com.token.kafka.connect.transforms;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.kafka.common.config.ConfigDef;
import org.apache.kafka.connect.connector.ConnectRecord;
import org.apache.kafka.connect.transforms.Transformation;

import java.util.Map;

/**
 * Custom SMT to convert value (Map/Struct) to JSON string for Redis sink.
 * 
 * The Redis sink connector requires the value to be a String or Bytes.
 * This transform converts Map objects to JSON strings.
 * 
 * Usage:
 * "transforms": "toJsonString",
 * "transforms.toJsonString.type": "com.token.kafka.connect.transforms.ValueToJsonString"
 */
public class ValueToJsonString<R extends ConnectRecord<R>> implements Transformation<R> {
    
    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
    
    @Override
    public void configure(Map<String, ?> configs) {
        // No configuration needed
    }
    
    @Override
    public R apply(R record) {
        if (record.value() == null) {
            return record;
        }
        
        Object value = record.value();
        String jsonString;
        
        try {
            if (value instanceof String) {
                // Already a string, pass through
                return record;
            } else if (value instanceof Map) {
                // Convert Map to JSON string
                jsonString = OBJECT_MAPPER.writeValueAsString(value);
            } else {
                // For other types, try to serialize
                jsonString = OBJECT_MAPPER.writeValueAsString(value);
            }
            
            return record.newRecord(
                record.topic(),
                record.kafkaPartition(),
                record.keySchema(),
                record.key(),
                null, // No schema for string value
                jsonString,
                record.timestamp(),
                record.headers()
            );
            
        } catch (Exception e) {
            throw new org.apache.kafka.connect.errors.DataException(
                "Failed to convert value to JSON string", e);
        }
    }
    
    @Override
    public ConfigDef config() {
        return new ConfigDef();
    }
    
    @Override
    public void close() {
        // No resources to close
    }
}
