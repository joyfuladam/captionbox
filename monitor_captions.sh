#!/bin/bash

# Caption Monitoring Script
# This script provides comprehensive monitoring of the captioning process
# to help identify pauses, hangs, and performance issues

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
LOG_FILE="caption_log.txt"
DOCKER_CONTAINER="caption-stable"
MONITOR_INTERVAL=5
ALERT_THRESHOLD=30  # seconds without activity
MAX_LOG_SIZE=100MB

echo -e "${BLUE}🎤 Caption Monitoring Dashboard${NC}"
echo "=================================="
echo "Monitoring interval: ${MONITOR_INTERVAL}s"
echo "Alert threshold: ${ALERT_THRESHOLD}s"
echo "Log file: ${LOG_FILE}"
echo "Container: ${DOCKER_CONTAINER}"
echo ""

# Function to check if Docker container is running
check_container_status() {
    if docker ps | grep -q "$DOCKER_CONTAINER"; then
        echo -e "${GREEN}✅ Container Status: RUNNING${NC}"
        return 0
    else
        echo -e "${RED}❌ Container Status: STOPPED${NC}"
        return 1
    fi
}

# Function to check container health
check_container_health() {
    local health=$(docker inspect --format='{{.State.Health.Status}}' "$DOCKER_CONTAINER" 2>/dev/null)
    if [ "$health" = "healthy" ]; then
        echo -e "${GREEN}✅ Health: HEALTHY${NC}"
    elif [ "$health" = "unhealthy" ]; then
        echo -e "${RED}❌ Health: UNHEALTHY${NC}"
    else
        echo -e "${YELLOW}⚠️  Health: $health${NC}"
    fi
}

# Function to monitor recent log activity
monitor_log_activity() {
    echo -e "\n${BLUE}📊 Recent Log Activity (last 10 entries):${NC}"
    
    if [ -f "$LOG_FILE" ]; then
        local last_activity=$(tail -1 "$LOG_FILE" | grep -o '^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}' || echo "No timestamp found")
        
        if [ "$last_activity" != "No timestamp found" ]; then
            local current_time=$(date '+%Y-%m-%d %H:%M:%S')
            local time_diff=$(($(date -d "$current_time" +%s) - $(date -d "$last_activity" +%s)))
            
            if [ $time_diff -gt $ALERT_THRESHOLD ]; then
                echo -e "${RED}⚠️  WARNING: No activity for ${time_diff}s (threshold: ${ALERT_THRESHOLD}s)${NC}"
            else
                echo -e "${GREEN}✅ Last activity: ${time_diff}s ago${NC}"
            fi
            
            echo "Last log entry: $last_activity"
            echo "Current time: $current_time"
        fi
        
        # Show recent log entries
        echo -e "\n${BLUE}Recent entries:${NC}"
        tail -10 "$LOG_FILE" | while IFS= read -r line; do
            if echo "$line" | grep -q "ERROR\|CRITICAL"; then
                echo -e "${RED}$line${NC}"
            elif echo "$line" | grep -q "WARNING"; then
                echo -e "${YELLOW}$line${NC}"
            elif echo "$line" | grep -q "INFO"; then
                echo -e "${BLUE}$line${NC}"
            else
                echo "$line"
            fi
        done
    else
        echo -e "${RED}❌ Log file not found: $LOG_FILE${NC}"
    fi
}

# Function to check for specific error patterns
check_error_patterns() {
    echo -e "\n${BLUE}🔍 Error Pattern Analysis:${NC}"
    
    if [ -f "$LOG_FILE" ]; then
        local error_count=$(grep -c "ERROR\|CRITICAL\|Exception\|Traceback" "$LOG_FILE" 2>/dev/null || echo "0")
        local warning_count=$(grep -c "WARNING" "$LOG_FILE" 2>/dev/null || echo "0")
        
        echo "Total errors: $error_count"
        echo "Total warnings: $warning_count"
        
        if [ "$error_count" -gt 0 ]; then
            echo -e "\n${RED}Recent errors:${NC}"
            grep "ERROR\|CRITICAL\|Exception\|Traceback" "$LOG_FILE" | tail -5 | while IFS= read -r line; do
                echo -e "${RED}$line${NC}"
            done
        fi
        
        if [ "$warning_count" -gt 0 ]; then
            echo -e "\n${YELLOW}Recent warnings:${NC}"
            grep "WARNING" "$LOG_FILE" | tail -3 | while IFS= read -r line; do
                echo -e "${YELLOW}$line${NC}"
            done
        fi
    fi
}

# Function to monitor system resources
monitor_system_resources() {
    echo -e "\n${BLUE}💻 System Resources:${NC}"
    
    # Container resource usage
    if docker ps | grep -q "$DOCKER_CONTAINER"; then
        echo -e "\n${BLUE}Container Resources:${NC}"
        docker stats "$DOCKER_CONTAINER" --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
    fi
    
    # Host system resources
    echo -e "\n${BLUE}Host System:${NC}"
    echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')%"
    echo "Memory Usage: $(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2}')"
    echo "Disk Usage: $(df -h / | awk 'NR==2{print $5}')"
}

# Function to check for audio device issues
check_audio_devices() {
    echo -e "\n${BLUE}🎵 Audio Device Status:${NC}"
    
    # Check host audio devices
    echo "Host ALSA devices:"
    aplay -l 2>/dev/null | head -10 || echo "No ALSA devices found"
    
    echo -e "\nHost PulseAudio sources:"
    pactl list sources short 2>/dev/null | head -5 || echo "PulseAudio not running or no sources"
    
    # Check container audio access
    if docker ps | grep -q "$DOCKER_CONTAINER"; then
        echo -e "\nContainer audio test:"
        docker exec "$DOCKER_CONTAINER" /usr/local/bin/test-audio 2>/dev/null || echo "Audio test failed in container"
    fi
}

# Function to check for network connectivity issues
check_network_connectivity() {
    echo -e "\n${BLUE}🌐 Network Connectivity:${NC}"
    
    # Check if the app is responding
    if curl -s http://localhost:8000/health >/dev/null 2>&1; then
        echo -e "${GREEN}✅ App health endpoint: RESPONDING${NC}"
    else
        echo -e "${RED}❌ App health endpoint: NOT RESPONDING${NC}"
    fi
    
    # Check WebSocket connectivity
    if netstat -tuln | grep -q ":8000"; then
        echo -e "${GREEN}✅ Port 8000: LISTENING${NC}"
    else
        echo -e "${RED}❌ Port 8000: NOT LISTENING${NC}"
    fi
}

# Function to check for potential hangs
check_for_hangs() {
    echo -e "\n${BLUE}⏰ Hang Detection:${NC}"
    
    # Check for long-running processes
    local long_processes=$(docker exec "$DOCKER_CONTAINER" ps aux 2>/dev/null | awk '$10 > 60 {print $2, $10, $11}' | head -5 || echo "Cannot check processes")
    
    if [ "$long_processes" != "Cannot check processes" ] && [ -n "$long_processes" ]; then
        echo -e "${YELLOW}⚠️  Long-running processes detected:${NC}"
        echo "$long_processes"
    else
        echo -e "${GREEN}✅ No long-running processes detected${NC}"
    fi
    
    # Check for stuck WebSocket connections
    local websocket_connections=$(netstat -an | grep ":8000" | grep ESTABLISHED | wc -l)
    echo "Active WebSocket connections: $websocket_connections"
}

# Function to show real-time log monitoring
start_realtime_monitoring() {
    echo -e "\n${BLUE}📺 Starting Real-time Log Monitoring (Press Ctrl+C to stop):${NC}"
    echo "Monitoring $LOG_FILE for new entries..."
    echo ""
    
    tail -f "$LOG_FILE" | while IFS= read -r line; do
        timestamp=$(date '+%H:%M:%S')
        if echo "$line" | grep -q "ERROR\|CRITICAL\|Exception\|Traceback"; then
            echo -e "[$timestamp] ${RED}$line${NC}"
        elif echo "$line" | grep -q "WARNING"; then
            echo -e "[$timestamp] ${YELLOW}$line${NC}"
        elif echo "$line" | grep -q "INFO"; then
            echo -e "[$timestamp] ${BLUE}$line${NC}"
        else
            echo -e "[$timestamp] $line"
        fi
    done
}

# Main monitoring loop
main_monitoring() {
    while true; do
        clear
        echo -e "${BLUE}🎤 Caption Monitoring Dashboard - $(date)${NC}"
        echo "=================================================="
        
        check_container_status
        check_container_health
        monitor_log_activity
        check_error_patterns
        monitor_system_resources
        check_audio_devices
        check_network_connectivity
        check_for_hangs
        
        echo -e "\n${BLUE}Press 'r' for real-time monitoring, 'q' to quit, or wait ${MONITOR_INTERVAL}s for next update${NC}"
        
        # Wait for user input or timeout
        read -t $MONITOR_INTERVAL -n 1 -s input
        case $input in
            r|R)
                start_realtime_monitoring
                ;;
            q|Q)
                echo -e "\n${GREEN}Monitoring stopped. Goodbye!${NC}"
                exit 0
                ;;
        esac
    done
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -r, --realtime      Start real-time log monitoring"
    echo "  -s, --status        Show current status only"
    echo "  -e, --errors        Show error analysis only"
    echo "  -a, --audio         Check audio device status only"
    echo ""
    echo "Examples:"
    echo "  $0                  # Start interactive monitoring dashboard"
    echo "  $0 -r               # Start real-time log monitoring"
    echo "  $0 -s               # Show current status and exit"
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_usage
        exit 0
        ;;
    -r|--realtime)
        start_realtime_monitoring
        exit 0
        ;;
    -s|--status)
        check_container_status
        check_container_health
        monitor_log_activity
        exit 0
        ;;
    -e|--errors)
        check_error_patterns
        exit 0
        ;;
    -a|--audio)
        check_audio_devices
        exit 0
        ;;
    "")
        main_monitoring
        ;;
    *)
        echo "Unknown option: $1"
        show_usage
        exit 1
        ;;
esac



