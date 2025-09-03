#!/bin/bash

# Simple Log Monitoring Script for Caption3B
# Watches logs in real-time to identify pauses, hangs, and issues

set -e

LOG_FILE="caption_log.txt"
DOCKER_CONTAINER="caption-stable"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 Caption Log Monitor${NC}"
echo "=========================="
echo "Log file: $LOG_FILE"
echo "Container: $DOCKER_CONTAINER"
echo "Press Ctrl+C to stop monitoring"
echo ""

# Function to check for activity gaps
check_activity_gaps() {
    local last_line="$1"
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Extract timestamp from log line
    local log_timestamp=$(echo "$last_line" | grep -o '^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}' || echo "")
    
    if [ -n "$log_timestamp" ]; then
        local time_diff=$(($(date -d "$current_time" +%s) - $(date -d "$log_timestamp" +%s)))
        
        if [ $time_diff -gt 60 ]; then
            echo -e "${RED}⚠️  WARNING: ${time_diff}s gap detected!${NC}"
        elif [ $time_diff -gt 30 ]; then
            echo -e "${YELLOW}⚠️  Notice: ${time_diff}s gap detected${NC}"
        fi
    fi
}

# Function to highlight important log entries
highlight_log_entry() {
    local line="$1"
    local timestamp=$(date '+%H:%M:%S')
    
    if echo "$line" | grep -q "ERROR\|CRITICAL\|Exception\|Traceback\|Failed\|Error"; then
        echo -e "[$timestamp] ${RED}$line${NC}"
    elif echo "$line" | grep -q "WARNING\|Warning"; then
        echo -e "[$timestamp] ${YELLOW}$line${NC}"
    elif echo "$line" | grep -q "Speech recognizer\|recognition\|caption\|transcript"; then
        echo -e "[$timestamp] ${GREEN}$line${NC}"
    elif echo "$line" | grep -q "INFO\|Info"; then
        echo -e "[$timestamp] ${BLUE}$line${NC}"
    else
        echo -e "[$timestamp] $line"
    fi
}

# Main monitoring loop
echo -e "${BLUE}Starting real-time log monitoring...${NC}"
echo ""

# Monitor logs with activity gap detection
tail -f "$LOG_FILE" | while IFS= read -r line; do
    # Check for activity gaps
    check_activity_gaps "$line"
    
    # Highlight and display the log entry
    highlight_log_entry "$line"
    
    # Add a small delay to prevent overwhelming output
    sleep 0.1
done



