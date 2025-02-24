#!/bin/bash

# Configuration
TIMEOUT=15  # Time in minutes before removing admin rights
LOGFILE="/var/log/temp_admin.log"
CURRENT_USER=$(stat -f%Su /dev/console) # Get the currently logged-in user
ADMIN_GROUP="admin"
TIMESTAMP_FILE="/var/tmp/temp_admin_$CURRENT_USER.timestamp"

# Check if user is already an admin
if groups "$CURRENT_USER" | grep -q "\b$ADMIN_GROUP\b"; then
    echo "User $CURRENT_USER is already an admin. No action taken."
    exit 1
fi

# Check if the script has already been run today
TODAY=$(date "+%Y-%m-%d")
if [ -f "$TIMESTAMP_FILE" ]; then
    LAST_RUN_DATE=$(cat "$TIMESTAMP_FILE")
    if [ "$LAST_RUN_DATE" == "$TODAY" ]; then
        echo "You have already requested admin access today. Try again tomorrow."
        exit 1
    fi
fi

# Prompt user for a reason (logged for audit)
echo "Enter the reason for requesting temporary admin access:"
read REASON

if [ -z "$REASON" ]; then
    echo "You must provide a reason."
    exit 1
fi

# Grant admin rights
sudo dseditgroup -o edit -a "$CURRENT_USER" -t user $ADMIN_GROUP
echo "$(date '+%Y-%m-%d %H:%M:%S') - $CURRENT_USER granted admin access. Reason: $REASON" | sudo tee -a $LOGFILE

# Save the timestamp to prevent multiple runs in one day
echo "$TODAY" > "$TIMESTAMP_FILE"

echo "You now have admin access for $TIMEOUT minutes."

# Schedule removal of admin rights
(sleep $((TIMEOUT * 60)) && sudo dseditgroup -o edit -d "$CURRENT_USER" -t user $ADMIN_GROUP && \
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $CURRENT_USER admin access revoked after timeout." | sudo tee -a $LOGFILE && \
    rm -f "$TIMESTAMP_FILE") &

exit 0
