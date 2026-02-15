/* //////////////////////////////////////////////////////////////////////////////////////////////////////
*
*       Project         :   Kafka Connect Source/Sink Connector SMT Function
*
*       File            :   RedisKeyFormatter.java
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
*       Custom SMT to format Redis keys with configurable patterns.
* 
*       Allows you to add prefixes, suffixes, or custom patterns to Redis keys.
*       Useful for namespacing, versioning, or multi-tenant Redis deployments.
* 
*       Configuration:
* 
*           - key.pattern: Pattern for formatting the key. Use ${key} as placeholder for the original key.
*                         Examples:
*                           "${key}"              -> "4111111111111111" (no change)
*                           "card:${key}"         -> "card:4111111111111111"
*                           "az1:card:${key}"     -> "az1:card:4111111111111111"
*                           "${key}:v1"           -> "4111111111111111:v1"
*                           "tenant:prod:${key}"  -> "tenant:prod:4111111111111111"
* 
*           - key.pattern.null.handling: How to handle null keys. Options:
*                         "pass" (default) - Pass through null keys unchanged
*                         "drop"           - Drop records with null keys (return null)
* 
*       Usage:
* 
*           "transforms": "formatRedisKey",
*           "transforms.formatRedisKey.type": "com.token.kafka.connect.transforms.RedisKeyFormatter",
*           "transforms.formatRedisKey.key.pattern": "card:${key}",
*           "transforms.formatRedisKey.key.pattern.null.handling": "pass"
* 
*       Example Integration in Sink Connector:
* 
*           "transforms": "filterKey,addTimestamp,selectFields,extractRedisKey,flattenKey,formatRedisKey,removeCardNumber,valueToJsonString",
*           "transforms.formatRedisKey.type": "com.token.kafka.connect.transforms.RedisKeyFormatter",
*           "transforms.formatRedisKey.key.pattern": "az1:card:${key}"
* 
*       This would transform:
*           Key: "4111111111111111"  ->  "az1:card:4111111111111111"
* 
*///////////////////////////////////////////////////////////////////////////////////////////////////////

package com.token.kafka.connect.transforms;

import org.apache.kafka.common.config.ConfigDef;
import org.apache.kafka.connect.connector.ConnectRecord;
import org.apache.kafka.connect.transforms.Transformation;
import org.apache.kafka.connect.transforms.util.SimpleConfig;

import java.util.Map;

public class RedisKeyFormatter<R extends ConnectRecord<R>> implements Transformation<R> {
    
    private static final String KEY_PATTERN_CONFIG = "key.pattern";
    private static final String NULL_HANDLING_CONFIG = "key.pattern.null.handling";
    private static final String PLACEHOLDER = "${key}";
    
    private String keyPattern;
    private String nullHandling;
    
    @Override
    public void configure(Map<String, ?> configs) {
        SimpleConfig config = new SimpleConfig(config(), configs);
        keyPattern = config.getString(KEY_PATTERN_CONFIG);
        nullHandling = config.getString(NULL_HANDLING_CONFIG);
        
        // Validate pattern contains placeholder
        if (keyPattern != null && !keyPattern.isEmpty() && !keyPattern.contains(PLACEHOLDER)) {
            throw new org.apache.kafka.connect.errors.ConnectException(
                "key.pattern must contain " + PLACEHOLDER + " placeholder. Got: " + keyPattern
            );
        }
    }
    
    @Override
    public R apply(R record) {
        if (record == null) {
            return null;
        }
        
        Object key = record.key();
        
        // Handle null keys according to configuration
        if (key == null) {
            if ("drop".equalsIgnoreCase(nullHandling)) {
                // Drop records with null keys
                return null;
            } else {
                // Pass through unchanged (default)
                return record;
            }
        }
        
        // If no pattern configured, pass through unchanged
        if (keyPattern == null || keyPattern.isEmpty()) {
            return record;
        }
        
        // Format the key using the pattern
        String originalKey = key.toString();
        String formattedKey = keyPattern.replace(PLACEHOLDER, originalKey);
        
        // Return new record with formatted key
        return record.newRecord(
            record.topic(),
            record.kafkaPartition(),
            null, // No schema for string key
            formattedKey,
            record.valueSchema(),
            record.value(),
            record.timestamp(),
            record.headers()
        );
    }
    
    @Override
    public ConfigDef config() {
        return new ConfigDef()
            .define(KEY_PATTERN_CONFIG, 
                    ConfigDef.Type.STRING, 
                    "${key}", 
                    ConfigDef.Importance.HIGH, 
                    "Pattern for formatting Redis keys. Use ${key} as placeholder for the original key. "
                    + "Examples: 'card:${key}', 'az1:${key}', '${key}:v1'")
            .define(NULL_HANDLING_CONFIG, 
                    ConfigDef.Type.STRING, 
                    "pass", 
                    ConfigDef.Importance.LOW, 
                    "How to handle null keys: 'pass' (pass through unchanged) or 'drop' (drop records with null keys)");
    }
    
    @Override
    public void close() {
        // No resources to close
    }
}
