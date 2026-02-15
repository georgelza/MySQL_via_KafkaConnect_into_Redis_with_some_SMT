/* //////////////////////////////////////////////////////////////////////////////////////////////////////
*
*       Project         :   Kafka Connect Source/Sink Connector SMT Function
*
*       File            :   AddTimestamp.java
*
*       Description     :   Kafka Connect Source/Sink Connector SMT Function
*
*       Created     	:   Feb 2026
*
*       copyright       :   Copyright 2026, - G Leonard, georgelza@gmail.com
*
*       GIT Repo        :   https://github.com/georgelza/MySQL_via_KafkaConnect_into_Redis_with_some_SMT.git
*
*       Custom SMT to add createdAt timestamp to the value.
* 
*       Configuration:
*           - timestamp.field: Name of the field to add (default: "createdAt")
*           - timestamp.format: Format of timestamp - "epoch" (milliseconds) or "iso8601" (default: "iso8601")
*           - timestamp.timezone: Timezone for ISO8601 format (default: "UTC")
* 
*       Usage:
*           "transforms": "addTimestamp",
*           "transforms.addTimestamp.type": "com.token.kafka.connect.transforms.AddTimestamp",
*           "transforms.addTimestamp.timestamp.field": "createdAt",
*           "transforms.addTimestamp.timestamp.format": "iso8601"
*
*///////////////////////////////////////////////////////////////////////////////////////////////////////

package com.token.kafka.connect.transforms;

import org.apache.kafka.common.config.ConfigDef;
import org.apache.kafka.connect.connector.ConnectRecord;
import org.apache.kafka.connect.data.Schema;
import org.apache.kafka.connect.data.SchemaBuilder;
import org.apache.kafka.connect.data.Struct;
import org.apache.kafka.connect.transforms.Transformation;
import org.apache.kafka.connect.transforms.util.SimpleConfig;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;
import java.util.TimeZone;

public class AddTimestamp<R extends ConnectRecord<R>> implements Transformation<R> {
    
    private static final String TIMESTAMP_FIELD_CONFIG    = "timestamp.field";
    private static final String TIMESTAMP_FORMAT_CONFIG   = "timestamp.format";
    private static final String TIMESTAMP_TIMEZONE_CONFIG = "timestamp.timezone";
    
    private String timestampField;
    private String timestampFormat;
    private SimpleDateFormat dateFormat;
    
    @Override
    public void configure(Map<String, ?> configs) {
        SimpleConfig config = new SimpleConfig(config(), configs);
        timestampField  = config.getString(TIMESTAMP_FIELD_CONFIG);
        timestampFormat = config.getString(TIMESTAMP_FORMAT_CONFIG);
        String timezone = config.getString(TIMESTAMP_TIMEZONE_CONFIG);
        
        if ("iso8601".equalsIgnoreCase(timestampFormat)) {
            dateFormat = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");
            dateFormat.setTimeZone(TimeZone.getTimeZone(timezone));
        }
    }
    
    @Override
    public R apply(R record) {
        if (record.value() == null) {
            return record;
        }
        
        Object timestampValue = generateTimestamp();
        Object updatedValue;
        Schema updatedSchema = null;
        
        // Handle different value types
        if (record.value() instanceof Map) {
            // JSON/Map value - add timestamp field
            @SuppressWarnings("unchecked")
            Map<String, Object> valueMap = new HashMap<>((Map<String, Object>) record.value());
            valueMap.put(timestampField, timestampValue);
            updatedValue = valueMap;
            
        } else if (record.value() instanceof Struct) {
            // Struct value - add timestamp field
            Struct originalStruct = (Struct) record.value();
            Schema originalSchema = originalStruct.schema();
            
            // Build new schema with timestamp field
            SchemaBuilder builder = SchemaBuilder.struct();
            if (originalSchema.name() != null) {
                builder.name(originalSchema.name());
            }
            
            // Copy existing fields
            for (org.apache.kafka.connect.data.Field field : originalSchema.fields()) {
                builder.field(field.name(), field.schema());
            }
            
            // Add timestamp field
            if ("epoch".equalsIgnoreCase(timestampFormat)) {
                builder.field(timestampField, Schema.INT64_SCHEMA);
            } else {
                builder.field(timestampField, Schema.STRING_SCHEMA);
            }
            updatedSchema = builder.build();
            
            // Copy values to new struct
            Struct updatedStruct = new Struct(updatedSchema);
            for (org.apache.kafka.connect.data.Field field : originalSchema.fields()) {
                updatedStruct.put(field.name(), originalStruct.get(field));
            }
            updatedStruct.put(timestampField, timestampValue);
            updatedValue = updatedStruct;
            
        } else {
            // Unsupported type - pass through unchanged
            return record;
        }
        
        return record.newRecord(
            record.topic(),
            record.kafkaPartition(),
            record.keySchema(),
            record.key(),
            updatedSchema,
            updatedValue,
            record.timestamp(),
            record.headers()
        );
    }
    
    private Object generateTimestamp() {
        long currentTimeMillis = System.currentTimeMillis();
        
        if ("epoch".equalsIgnoreCase(timestampFormat)) {
            return currentTimeMillis;
        } else {
            // ISO8601 format
            return dateFormat.format(new Date(currentTimeMillis));
        }
    }
    
    @Override
    public ConfigDef config() {
        return new ConfigDef()
            .define(TIMESTAMP_FIELD_CONFIG, 
                    ConfigDef.Type.STRING, 
                    "createdAt", 
                    ConfigDef.Importance.MEDIUM, 
                    "Name of the field to add for timestamp")
            .define(TIMESTAMP_FORMAT_CONFIG, 
                    ConfigDef.Type.STRING, 
                    "iso8601", 
                    ConfigDef.Importance.MEDIUM, 
                    "Format of timestamp: 'epoch' (milliseconds since epoch) or 'iso8601' (ISO 8601 format)")
            .define(TIMESTAMP_TIMEZONE_CONFIG, 
                    ConfigDef.Type.STRING, 
                    "UTC", 
                    ConfigDef.Importance.LOW, 
                    "Timezone for ISO8601 format (e.g., 'UTC', 'Africa/Johannesburg')");
    }
    
    @Override
    public void close() {
        // No resources to close
    }
}
