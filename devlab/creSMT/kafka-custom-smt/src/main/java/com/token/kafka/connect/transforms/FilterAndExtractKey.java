/* //////////////////////////////////////////////////////////////////////////////////////////////////////
*
*       Project         :   Kafka Connect Source/Sink Connector SMT Function
*
*       File            :   FilterAndExtractKey.java
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
*       Source Engine:
* 
*       1. Filters records - only passes through if specified fields are non-null/non-empty
*       2. Extracts plain string key from struct key
* 
*       Configuration:
*  
*           - key.field:     Field name to extract from key struct (default: "key")
*           - filter.fields: Comma-separated list of VALUE fields that must be populated (e.g., "cardNumber,discountDesc")
*           - filter.mode:   "all" (all fields must be present) or "any" (at least one field must be present) - default: "all"
* 
*       Usage in connector config:
* 
*           "transforms": "filterAndKey",
*           "transforms.filterAndKey.type": "com.token.kafka.connect.transforms.FilterAndExtractKey",
*           "transforms.filterAndKey.key.field": "key",
*           "transforms.filterAndKey.filter.fields": "cardNumber,discountDesc",
*           "transforms.filterAndKey.filter.mode": "all"
* 
*///////////////////////////////////////////////////////////////////////////////////////////////////////

package com.token.kafka.connect.transforms;

import org.apache.kafka.common.config.ConfigDef;
import org.apache.kafka.connect.connector.ConnectRecord;
import org.apache.kafka.connect.data.Field;
import org.apache.kafka.connect.data.Struct;
import org.apache.kafka.connect.transforms.Transformation;
import org.apache.kafka.connect.transforms.util.SimpleConfig;

import java.util.Arrays;
import java.util.List;
import java.util.Map;

public class FilterAndExtractKey<R extends ConnectRecord<R>> implements Transformation<R> {
    
    private static final String KEY_FIELD_CONFIG     = "key.field";
    private static final String FILTER_FIELDS_CONFIG = "filter.fields";
    private static final String FILTER_MODE_CONFIG   = "filter.mode";
    
    private String keyFieldName;
    private List<String> filterFields;
    private String filterMode;
    
    @Override
    public void configure(Map<String, ?> configs) {
        SimpleConfig config = new SimpleConfig(config(), configs);
        
        keyFieldName = config.getString(KEY_FIELD_CONFIG);
        
        String fieldsStr = config.getString(FILTER_FIELDS_CONFIG);
        if (fieldsStr != null && !fieldsStr.trim().isEmpty()) {
            filterFields = Arrays.asList(fieldsStr.split("\\s*,\\s*"));
        }
        
        filterMode = config.getString(FILTER_MODE_CONFIG);
    }
    
    @Override
    public R apply(R record) {
        // Step 1: Filter based on value fields
        if (filterFields != null && !filterFields.isEmpty()) {
            if (!passesFilter(record.value())) {
                // Record doesn't pass filter - drop it
                return null;
            }
        }
        
        // Step 2: Extract clean string key
        Object newKey = extractKey(record.key());
        
        // Return new record with extracted key
        return record.newRecord(
            record.topic(),
            record.kafkaPartition(),
            null, // No schema for string key
            newKey,
            record.valueSchema(),
            record.value(),
            record.timestamp(),
            record.headers()
        );
    }
    
    /**
     * Check if the record value passes the filter criteria
     */
    private boolean passesFilter(Object value) {
        if (value == null) {
            return false;
        }
        
        if (!(value instanceof Struct)) {
            // If not a struct, can't filter on fields
            return true;
        }
        
        Struct struct = (Struct) value;
        boolean allMode = "all".equalsIgnoreCase(filterMode);
        
        int matchCount = 0;
        for (String fieldName : filterFields) {
            Field field = struct.schema().field(fieldName);
            
            if (field == null) {
                // Field doesn't exist in schema
                if (allMode) {
                    return false; // In "all" mode, missing field = fail
                }
                continue;
            }
            
            Object fieldValue = struct.get(field);
            
            if (isFieldPopulated(fieldValue)) {
                matchCount++;
                if (!allMode) {
                    // In "any" mode, one match is enough
                    return true;
                }
            } else if (allMode) {
                // In "all" mode, one empty field = fail
                return false;
            }
        }
        
        // In "all" mode: must have matched all fields
        // In "any" mode: must have matched at least one (already returned true above if so)
        return allMode ? (matchCount == filterFields.size()) : (matchCount > 0);
    }
    
    /**
     * Check if a field value is considered "populated"
     */
    private boolean isFieldPopulated(Object value) {
        if (value == null) {
            return false;
        }
        
        // Check for empty strings
        if (value instanceof String) {
            String str = (String) value;
            return !str.trim().isEmpty();
        }
        
        // All other non-null values are considered populated
        return true;
    }
    
    /**
     * Extract plain string key from struct key
     */
    private Object extractKey(Object key) {
        if (key == null) {
            return null;
        }
        
        // If key is a Struct, extract the specified field
        if (key instanceof Struct) {
            Struct structKey = (Struct) key;
            Field field = structKey.schema().field(keyFieldName);
            
            if (field != null) {
                Object fieldValue = structKey.get(field);
                return fieldValue != null ? fieldValue.toString() : null;
            }
        }
        
        // If key is already a string or other primitive, return as-is
        return key.toString();
    }
    
    @Override
    public ConfigDef config() {
        return new ConfigDef()
            .define(KEY_FIELD_CONFIG, 
                    ConfigDef.Type.STRING, 
                    "key", 
                    ConfigDef.Importance.HIGH, 
                    "Field name to extract from struct key (e.g., 'key', '_key')")
            .define(FILTER_FIELDS_CONFIG, 
                    ConfigDef.Type.STRING, 
                    null, 
                    ConfigDef.Importance.MEDIUM, 
                    "Comma-separated list of value fields that must be populated (e.g., 'cardNumber,tokenCardNumber') for record to be extracted")
            .define(FILTER_MODE_CONFIG, 
                    ConfigDef.Type.STRING, 
                    "all", 
                    ConfigDef.Importance.LOW, 
                    "Filter mode: 'all' (all fields must be populated) or 'any' (at least one field must be populated)");
    }
    
    @Override
    public void close() {
        // No resources to close
    }
}
