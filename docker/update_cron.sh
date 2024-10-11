#!/bin/sh

# Define the cron job and markers
MARKER_BEGIN="#####dockerfile-begin"
MARKER_END="#####dockerfile-end"
CRON_JOB="* * * * * docker exec <container_name> python /app/my_script.py"

# The cron file location
CRON_FILE="/etc/cron.d/my_crontab"

# Check if the markers exist
if ! grep -q "$MARKER_BEGIN" "$CRON_FILE"; then
    # If markers don't exist, append them to the cron file
    echo "$MARKER_BEGIN" >> "$CRON_FILE"
    echo "$CRON_JOB" >> "$CRON_FILE"
    echo "$MARKER_END" >> "$CRON_FILE"
else
    # If markers exist, replace the content between them
    sed -i "/$MARKER_BEGIN/,/$MARKER_END/{//!d;}; /$MARKER_BEGIN/a $CRON_JOB" "$CRON_FILE"
fi

# Ensure the cron file has the correct permissions
chmod 0644 "$CRON_FILE"
