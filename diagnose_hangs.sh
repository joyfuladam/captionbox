#!/bin/bash

# Hang Diagnosis Script for Caption3B
# Identifies common causes of pauses and hangs

set -e

DOCKER_CONTAINER="caption-stable"
LOG_FILE="caption_log.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 Caption Hang Diagnosis${NC}"
echo "============================="
echo ""

# Function to check container status
check_container_status() {
    echo -e "${BLUE}📦 Container Status:${NC}"
    
    if docker ps | grep -q "$DOCKER_CONTAINER"; then
        echo -e "${GREEN}✅ Container is running${NC}"
        
        # Check health status
        local health=$(docker inspect --format='{{.State.Health.Status}}' "$DOCKER_CONTAINER" 2>/dev/null)
        echo "Health status: $health"
        
        # Check uptime
        local uptime=$(docker inspect --format='{{.State.StartedAt}}' "$DOCKER_CONTAINER" 2>/dev/null)
        echo "Started at: $uptime"
        
        # Check resource usage
        echo -e "\nResource usage:"
        docker stats "$DOCKER_CONTAINER" --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
        
    else
        echo -e "${RED}❌ Container is not running${NC}"
        return 1
    fi
    echo ""
}

# Function to check for log activity gaps
check_log_gaps() {
    echo -e "${BLUE}📊 Log Activity Analysis:${NC}"
    
    if [ ! -f "$LOG_FILE" ]; then
        echo -e "${RED}❌ Log file not found: $LOG_FILE${NC}"
        return 1
    fi
    
    # Get last 20 log entries with timestamps
    echo "Last 20 log entries:"
    tail -20 "$LOG_FILE" | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' | tail -10
    
    # Check for gaps in activity
    echo -e "\nActivity gap analysis:"
    local last_timestamp=$(tail -1 "$LOG_FILE" | grep -o '^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}' || echo "")
    
    if [ -n "$last_timestamp" ]; then
        local current_time=$(date '+%Y-%m-%d %H:%M:%S')
        local time_diff=$(($(date -d "$current_time" +%s) - $(date -d "$last_timestamp" +%s)))
        
        if [ $time_diff -gt 300 ]; then
            echo -e "${RED}⚠️  CRITICAL: No activity for ${time_diff}s (${time_diff}s > 5 minutes)${NC}"
        elif [ $time_diff -gt 60 ]; then
            echo -e "${YELLOW}⚠️  WARNING: No activity for ${time_diff}s (${time_diff}s > 1 minute)${NC}"
        else
            echo -e "${GREEN}✅ Recent activity: ${time_diff}s ago${NC}"
        fi
        
        echo "Last log entry: $last_timestamp"
        echo "Current time: $current_time"
    fi
    echo ""
}

# Function to check for error patterns
check_error_patterns() {
    echo -e "${BLUE}🚨 Error Analysis:${NC}"
    
    if [ ! -f "$LOG_FILE" ]; then
        echo "No log file to analyze"
        return 1
    fi
    
    # Count different types of errors
    local error_count=$(grep -c "ERROR\|CRITICAL\|Exception\|Traceback" "$LOG_FILE" 2>/dev/null || echo "0")
    local warning_count=$(grep -c "WARNING" "$LOG_FILE" 2>/dev/null || echo "0")
    local failed_count=$(grep -c "Failed\|failed\|Failure\|failure" "$LOG_FILE" 2>/dev/null || echo "0")
    
    echo "Total errors: $error_count"
    echo "Total warnings: $warning_count"
    echo "Total failures: $failed_count"
    
    if [ "$error_count" -gt 0 ]; then
        echo -e "\n${RED}Recent errors (last 5):${NC}"
        grep "ERROR\|CRITICAL\|Exception\|Traceback" "$LOG_FILE" | tail -5 | while IFS= read -r line; do
            echo -e "${RED}$line${NC}"
        done
    fi
    
    if [ "$warning_count" -gt 0 ]; then
        echo -e "\n${YELLOW}Recent warnings (last 3):${NC}"
        grep "WARNING" "$LOG_FILE" | tail -3 | while IFS= read -r line; do
            echo -e "${YELLOW}$line${NC}"
        done
    fi
    echo ""
}

# Function to check system resources
check_system_resources() {
    echo -e "${BLUE}💻 System Resources:${NC}"
    
    # Host system
    echo "Host CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')%"
    echo "Host Memory Usage: $(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2}')"
    echo "Host Disk Usage: $(df -h / | awk 'NR==2{print $5}')"
    
    # Check for high resource usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')
    local mem_usage=$(free -m | awk 'NR==2{printf "%.1f", $3*100/$2}')
    
    if (( $(echo "$cpu_usage > 80" | bc -l) )); then
        echo -e "${YELLOW}⚠️  High CPU usage detected: ${cpu_usage}%${NC}"
    fi
    
    if (( $(echo "$mem_usage > 80" | bc -l) )); then
        echo -e "${YELLOW}⚠️  High memory usage detected: ${mem_usage}%${NC}"
    fi
    echo ""
}

# Function to check audio device status
check_audio_devices() {
    echo -e "${BLUE}🎵 Audio Device Status:${NC}"
    
    # Check host audio
    echo "Host ALSA devices:"
    aplay -l 2>/dev/null | head -5 || echo "No ALSA devices found"
    
    echo -e "\nHost PulseAudio sources:"
    pactl list sources short 2>/dev/null | head -3 || echo "PulseAudio not running or no sources"
    
    # Check container audio access
    if docker ps | grep -q "$DOCKER_CONTAINER"; then
        echo -e "\nContainer audio test:"
        docker exec "$DOCKER_CONTAINER" /usr/local/bin/test-audio 2>/dev/null || echo "Audio test failed in container"
    fi
    echo ""
}

# Function to check network connectivity
check_network_connectivity() {
    echo -e "${BLUE}🌐 Network Connectivity:${NC}"
    
    # Check app endpoints
    if curl -s http://localhost:8000/health >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Health endpoint: RESPONDING${NC}"
    else
        echo -e "${RED}❌ Health endpoint: NOT RESPONDING${NC}"
    fi
    
    if curl -s http://localhost:8000/recognition_status >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Recognition status: RESPONDING${NC}"
    else
        echo -e "${RED}❌ Recognition status: NOT RESPONDING${NC}"
    fi
    
    # Check port status
    if netstat -tuln | grep -q ":8000"; then
        echo -e "${GREEN}✅ Port 8000: LISTENING${NC}"
    else
        echo -e "${RED}❌ Port 8000: NOT LISTENING${NC}"
    fi
    
    # Check WebSocket connections
    local ws_connections=$(netstat -an | grep ":8000" | grep ESTABLISHED | wc -l)
    echo "Active WebSocket connections: $ws_connections"
    echo ""
}

# Function to check for common hang causes
check_hang_causes() {
    echo -e "${BLUE}⏰ Hang Cause Analysis:${NC}"
    
    # Check for stuck processes
    if docker ps | grep -q "$DOCKER_CONTAINER"; then
        echo "Container process status:"
        docker exec "$DOCKER_CONTAINER" ps aux 2>/dev/null | head -10 || echo "Cannot check processes"
        
        # Check for long-running processes
        local long_procs=$(docker exec "$DOCKER_CONTAINER" ps aux 2>/dev/null | awk '$10 > 60 {print $2, $10, $11}' | head -3 || echo "None")
        if [ "$long_procs" != "None" ] && [ -n "$long_procs" ]; then
            echo -e "\n${YELLOW}⚠️  Long-running processes detected:${NC}"
            echo "$long_procs"
        fi
    fi
    
    # Check for file locks or permission issues
    echo -e "\nFile permission check:"
    ls -la *.log *.txt 2>/dev/null | head -5 || echo "No log files found"
    
    # Check for disk space issues
    local disk_usage=$(df -h . | awk 'NR==2{print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 90 ]; then
        echo -e "${RED}⚠️  CRITICAL: Low disk space: ${disk_usage}%${NC}"
    elif [ "$disk_usage" -gt 80 ]; then
        echo -e "${YELLOW}⚠️  WARNING: High disk usage: ${disk_usage}%${NC}"
    else
        echo -e "${GREEN}✅ Disk usage: ${disk_usage}%${NC}"
    fi
    echo ""
}

# Function to provide recommendations
provide_recommendations() {
    echo -e "${BLUE}💡 Recommendations:${NC}"
    
    # Check if container is healthy
    local health=$(docker inspect --format='{{.State.Health.Status}}' "$DOCKER_CONTAINER" 2>/dev/null)
    if [ "$health" != "healthy" ]; then
        echo -e "${YELLOW}• Container health is $health - consider restarting${NC}"
    fi
    
    # Check for recent errors
    local recent_errors=$(grep -c "ERROR\|CRITICAL\|Exception\|Traceback" "$LOG_FILE" 2>/dev/null | tail -100 || echo "0")
    if [ "$recent_errors" -gt 5 ]; then
        echo -e "${YELLOW}• High error count detected - check logs for patterns${NC}"
    fi
    
    # Check for activity gaps
    local last_timestamp=$(tail -1 "$LOG_FILE" | grep -o '^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}' || echo "")
    if [ -n "$last_timestamp" ]; then
        local current_time=$(date '+%Y-%m-%d %H:%M:%S')
        local time_diff=$(($(date -d "$current_time" +%s) - $(date -d "$last_timestamp" +%s)))
        
        if [ $time_diff -gt 300 ]; then
            echo -e "${RED}• CRITICAL: System appears to be hung - restart recommended${NC}"
        elif [ $time_diff -gt 60 ]; then
            echo -e "${YELLOW}• WARNING: Activity gap detected - monitor closely${NC}"
        fi
    fi
    
    echo -e "\n${BLUE}Monitoring commands:${NC}"
    echo "• Real-time logs: ./watch_logs.sh"
    echo "• Full dashboard: ./monitor_captions.sh"
    echo "• Container logs: docker logs caption-stable -f"
    echo ""
}

# Main execution
main() {
    echo "Starting hang diagnosis..."
    echo ""
    
    check_container_status
    check_log_gaps
    check_error_patterns
    check_system_resources
    check_audio_devices
    check_network_connectivity
    check_hang_causes
    provide_recommendations
    
    echo -e "${BLUE}Diagnosis complete!${NC}"
}

# Run main function
main



