#!/bin/bash

# Setup cron job for audio fix
# This is an alternative to the systemd service

echo "Setting up cron job for audio fix..."

# Create the cron job entry
CRON_JOB="@reboot sleep 30 && /home/nwtech/caption3b/audio-fix.sh >> /home/nwtech/caption3b/logs/audio-fix.log 2>&1"

# Add to crontab
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

echo "Cron job added successfully!"
echo "The audio fix script will run 30 seconds after each reboot"
echo "Logs will be written to /home/nwtech/caption3b/logs/audio-fix.log" 