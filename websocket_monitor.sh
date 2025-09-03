#!/bin/bash

# WebSocket Connection Monitor for Caption3B
# Monitors WebSocket connections in real-time to prevent caption pauses

set -e

DOCKER_CONTAINER="caption-stable"
LOG_FILE="caption_log.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔌 WebSocket Connection Monitor${NC}"
echo "================================="
echo "Monitoring WebSocket connections for stability issues"
echo "Press Ctrl+C to stop monitoring"
echo ""

# Function to monitor WebSocket connections in real-time
monitor_websocket_connections() {
    echo -e "${GREEN}📡 Starting WebSocket Connection Monitoring...${NC}"
    echo ""
    
    # Monitor for WebSocket events
    docker logs "$DOCKER_CONTAINER" -f --tail 0 | while IFS= read -r line; do
        timestamp=$(date '+%H:%M:%S')
        
        # Highlight different types of WebSocket events
        if echo "$line" | grep -q "WebSocket.*accepted"; then
            echo -e "[$timestamp] ${GREEN}✅ NEW CONNECTION: $line${NC}"
        elif echo "$line" | grep -q "connection open"; then
            echo -e "[$timestamp] ${GREEN}🔗 CONNECTION OPEN: $line${NC}"
        elif echo "$line" | grep -q "connection closed"; then
            echo -e "[$timestamp] ${RED}❌ CONNECTION CLOSED: $line${NC}"
        elif echo "$line" | grep -q "disconnect\|timeout\|error\|Error\|ERROR"; then
            echo -e "[$timestamp] ${RED}🚨 CONNECTION ERROR: $line${NC}"
        elif echo "$line" | grep -q "WebSocket"; then
            echo -e "[$timestamp] ${BLUE}🔌 WEBSOCKET EVENT: $line${NC}"
        fi
        
        # Check for potential caption pause indicators
        if echo "$line" | grep -q "connection closed"; then
            echo -e "${YELLOW}⚠️  WARNING: Connection drop detected - may cause caption pause${NC}"
        fi
    done
}

# Function to check connection health
check_connection_health() {
    echo -e "${BLUE}🏥 Connection Health Check:${NC}"
    
    # Check if container is running
    if ! docker ps | grep -q "$DOCKER_CONTAINER"; then
        echo -e "${RED}❌ Container is not running${NC}"
        return 1
    fi
    
    # Check recent connection activity
    echo "Recent WebSocket activity (last 50 lines):"
    docker logs "$DOCKER_CONTAINER" --tail 50 | grep -E "(WebSocket|connection)" | tail -10
    
    # Count connections
    local recent_connections=$(docker logs "$DOCKER_CONTAINER" --tail 1000 | grep -c "WebSocket.*accepted" || echo "0")
    local recent_closes=$(docker logs "$DOCKER_CONTAINER" --tail 1000 | grep -c "connection closed" || echo "0")
    
    echo -e "\n${BLUE}Connection Statistics:${NC}"
    echo "Recent connections: $recent_connections"
    echo "Recent closes: $recent_closes"
    
    if [ "$recent_closes" -gt 0 ] && [ "$recent_connections" -gt 0 ]; then
        local drop_rate=$((recent_closes * 100 / recent_connections))
        if [ $drop_rate -gt 50 ]; then
            echo -e "${RED}⚠️  HIGH CONNECTION DROP RATE: ${drop_rate}%${NC}"
        elif [ $drop_rate -gt 20 ]; then
            echo -e "${YELLOW}⚠️  MODERATE CONNECTION DROP RATE: ${drop_rate}%${NC}"
        else
            echo -e "${GREEN}✅ Good connection stability: ${drop_rate}% drop rate${NC}"
        fi
    fi
}

# Function to test connection stability
test_connection_stability() {
    echo -e "${BLUE}🧪 Testing Connection Stability:${NC}"
    
    # Monitor for a short period to assess stability
    echo "Monitoring connections for 30 seconds..."
    echo "Press Ctrl+C to stop early"
    echo ""
    
    local start_time=$(date +%s)
    local connections=0
    local drops=0
    
    # Monitor for 30 seconds
    timeout 30s docker logs "$DOCKER_CONTAINER" -f --tail 0 | while IFS= read -r line; do
        if echo "$line" | grep -q "WebSocket.*accepted"; then
            connections=$((connections + 1))
            echo -e "${GREEN}✅ Connection $connections established${NC}"
        elif echo "$line" | grep -q "connection closed"; then
            drops=$((drops + 1))
            echo -e "${RED}❌ Connection drop $drops detected${NC}"
        fi
    done
    
    echo -e "\n${BLUE}Stability Test Results:${NC}"
    echo "Connections established: $connections"
    echo "Connection drops: $drops"
    
    if [ $drops -eq 0 ]; then
        echo -e "${GREEN}✅ Excellent connection stability${NC}"
    elif [ $drops -lt $((connections / 10)) ]; then
        echo -e "${GREEN}✅ Good connection stability${NC}"
    else
        echo -e "${YELLOW}⚠️  Connection stability needs improvement${NC}"
    fi
}

# Function to show connection recommendations
show_recommendations() {
    echo -e "\n${BLUE}💡 Connection Stability Recommendations:${NC}"
    
    echo -e "\n${GREEN}For Caption Pause Prevention:${NC}"
    echo "1. Monitor this script during captioning sessions"
    echo "2. Watch for connection drops that coincide with pauses"
    echo "3. Implement client-side reconnection logic"
    echo "4. Check network stability between client and server"
    
    echo -e "\n${GREEN}Monitoring Best Practices:${NC}"
    echo "• Run this monitor during live captioning"
    echo "• Note timestamps of connection drops"
    echo "• Correlate drops with caption pauses"
    echo "• Monitor network performance during issues"
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -m, --monitor       Start real-time connection monitoring"
    echo "  -c, --check         Check current connection health"
    echo "  -t, --test          Test connection stability"
    echo "  -r, --recommend     Show connection recommendations"
    echo ""
    echo "Examples:"
    echo "  $0                  # Show this help"
    echo "  $0 -m               # Start real-time monitoring"
    echo "  $0 -c               # Check connection health"
    echo "  $0 -t               # Test connection stability"
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_usage
        exit 0
        ;;
    -m|--monitor)
        monitor_websocket_connections
        exit 0
        ;;
    -c|--check)
        check_connection_health
        exit 0
        ;;
    -t|--test)
        test_connection_stability
        exit 0
        ;;
    -r|--recommend)
        show_recommendations
        exit 0
        ;;
    "")
        show_usage
        ;;
    *)
        echo "Unknown option: $1"
        show_usage
        exit 1
        ;;
esac



