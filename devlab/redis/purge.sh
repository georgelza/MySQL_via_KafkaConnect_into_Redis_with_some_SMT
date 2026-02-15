#!/bin/bash

# --- Configuration ---
REDIS_HOST="${REDIS_HOST:-127.0.0.1}"
REDIS_PORT="${REDIS_PORT:-6379}"
DB_INDEX="${DB_INDEX:-0}" 
KEY_PATTERN="${KEY_PATTERN:-card:*}" 
HOURS_OLD="${HOURS_OLD:-24}"
AUTO_APPROVE="${AUTO_APPROVE:-n}" 

# Record Start Time
START_TIME=$(date +%s)
START_STR=$(date)

# Calculate threshold for BSD/macOS Date
THRESHOLD_DATE=$(date -v-"${HOURS_OLD}"H +%s)

echo "--- Execution Started: $START_STR ---"
echo "Target:   $REDIS_HOST:$REDIS_PORT (DB $DB_INDEX)"
echo "Pattern: '$KEY_PATTERN' | Threshold: $HOURS_OLD hours"

# 1. Scan and Identify
DELETE_LIST=()
# We use -n to ensure we are in the correct DB index
KEYS=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -n "$DB_INDEX" keys "$KEY_PATTERN")

for KEY in $KEYS; do
    VALUE=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -n "$DB_INDEX" GET "$KEY")
    CREATED_AT=$(echo "$VALUE" | jq -r '.createdAt // empty')
    
    if [ -n "$CREATED_AT" ]; then
        # BSD Date conversion (stripping milliseconds)
        CREATED_TIME=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${CREATED_AT%.*}" +%s 2>/dev/null)
        
        if [ $? -eq 0 ] && [ "$CREATED_TIME" -lt "$THRESHOLD_DATE" ]; then
            DELETE_LIST+=("$KEY")
        fi
    fi
done

TOTAL_TO_DELETE=${#DELETE_LIST[@]}

if [ "$TOTAL_TO_DELETE" -eq 0 ]; then
    echo "No keys found matching the criteria."
    exit 0
fi

# 2. Permission Request
echo "----------------------------"
echo "Found $TOTAL_TO_DELETE keys to remove."

if [[ "$AUTO_APPROVE" != "y" && "$AUTO_APPROVE" != "Y" ]]; then
    read -p "Proceed with deletion? (y/N): " CONFIRM
    # Default to 'n' if user just hits enter
    CONFIRM="${CONFIRM:-n}"
else
    CONFIRM="y"
    echo "Auto-approve enabled via variable."
fi

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Aborted by user."
    exit 0
fi

# 3. Perform Deletion (Optimized with xargs)
echo "Deleting... please wait."
if [ "$TOTAL_TO_DELETE" -gt 0 ]; then
    # Passing keys to xargs allows deleting in batches rather than one-by-one
    printf "%s\n" "${DELETE_LIST[@]}" | xargs -n 100 redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -n "$DB_INDEX" DEL > /dev/null
fi

# 4. Record End Time and Duration
END_TIME=$(date +%s)
END_STR=$(date)
DURATION=$((END_TIME - START_TIME))

echo "----------------------------"
echo "Execution Ended: $END_STR"
echo "Total Keys Deleted: $TOTAL_TO_DELETE"
echo "Total Run Time: ${DURATION} seconds"