#!/bin/bash

# WebSocket Connection Fix Script for Caption3B
# Improves WebSocket connection stability and monitors for issues

set -e

DOCKER_CONTAINER="caption-stable"
LOG_FILE="caption_log.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔌 WebSocket Connection Fix Script${NC}"
echo "====================================="
echo ""

# Function to check current WebSocket connections
check_websocket_connections() {
    echo -e "${BLUE}📡 Current WebSocket Status:${NC}"
    
    # Check if container is running
    if ! docker ps | grep -q "$DOCKER_CONTAINER"; then
        echo -e "${RED}❌ Container is not running${NC}"
        return 1
    fi
    
    # Get recent WebSocket connections
    echo "Recent WebSocket connections:"
    docker logs "$DOCKER_CONTAINER" --tail 100 | grep -E "(WebSocket.*accepted|connection open|connection closed)" | tail -10
    
    # Count active connections
    local active_connections=$(docker logs "$DOCKER_CONTAINER" --tail 1000 | grep -c "connection open" || echo "0")
    local closed_connections=$(docker logs "$DOCKER_CONTAINER" --tail 1000 | grep -c "connection closed" || echo "0")
    
    echo -e "\n${BLUE}Connection Statistics:${NC}"
    echo "Active connections: $active_connections"
    echo "Closed connections: $closed_connections"
    
    if [ "$active_connections" -gt 0 ]; then
        echo -e "${GREEN}✅ WebSocket server is accepting connections${NC}"
    else
        echo -e "${YELLOW}⚠️  No active WebSocket connections detected${NC}"
    fi
}

# Function to check for connection errors
check_connection_errors() {
    echo -e "\n${BLUE}🚨 Connection Error Analysis:${NC}"
    
    # Look for common WebSocket errors
    local errors=$(docker logs "$DOCKER_CONTAINER" --tail 2000 | grep -i -E "(error|exception|failed|timeout|disconnect|close)" | head -10)
    
    if [ -n "$errors" ]; then
        echo -e "${YELLOW}⚠️  Recent connection issues detected:${NC}"
        echo "$errors"
    else
        echo -e "${GREEN}✅ No recent connection errors detected${NC}"
    fi
    
    # Check for connection drops
    local drops=$(docker logs "$DOCKER_CONTAINER" --tail 2000 | grep -c "connection closed" || echo "0")
    if [ "$drops" -gt 5 ]; then
        echo -e "${YELLOW}⚠️  Multiple connection drops detected: $drops${NC}"
    fi
}

# Function to check network connectivity
check_network_connectivity() {
    echo -e "\n${BLUE}🌐 Network Connectivity Check:${NC}"
    
    # Check if the app is responding
    if curl -s http://localhost:8000/health >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Health endpoint: RESPONDING${NC}"
    else
        echo -e "${RED}❌ Health endpoint: NOT RESPONDING${NC}"
        return 1
    fi
    
    # Check if port 8000 is listening
    if ss -tuln | grep -q ":8000"; then
        echo -e "${GREEN}✅ Port 8000: LISTENING${NC}"
    else
        echo -e "${RED}❌ Port 8000: NOT LISTENING${NC}"
    fi
    
    # Check for any network errors
    local network_errors=$(docker logs "$DOCKER_CONTAINER" --tail 1000 | grep -i -E "(network|connection|timeout|refused)" | head -5)
    if [ -n "$network_errors" ]; then
        echo -e "${YELLOW}⚠️  Network-related issues:${NC}"
        echo "$network_errors"
    fi
}

# Function to optimize WebSocket settings
optimize_websocket_settings() {
    echo -e "\n${BLUE}🔧 Optimizing WebSocket Settings:${NC}"
    
    # Check current container resource limits
    echo "Current container resource limits:"
    docker stats "$DOCKER_CONTAINER" --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
    
    # Check if there are any WebSocket-specific configurations
    echo -e "\n${BLUE}WebSocket Configuration Recommendations:${NC}"
    echo "• Ensure client-side reconnection logic is implemented"
    echo "• Set appropriate WebSocket timeout values"
    echo "• Implement connection health monitoring"
    echo "• Add automatic reconnection on connection drops"
}

# Function to test WebSocket stability
test_websocket_stability() {
    echo -e "\n${BLUE}🧪 Testing WebSocket Stability:${NC}"
    
    # Start monitoring WebSocket connections in real-time
    echo "Starting WebSocket connection monitoring..."
    echo "Press Ctrl+C to stop monitoring"
    echo ""
    
    # Monitor for new connections and drops
    docker logs "$DOCKER_CONTAINER" -f --tail 0 | grep -E "(WebSocket|connection|disconnect|close|timeout|error)" &
    local monitor_pid=$!
    
    # Wait for user input
    echo "Monitoring active... Press Enter to stop"
    read -r
    
    # Stop monitoring
    kill $monitor_pid 2>/dev/null || true
    echo "Monitoring stopped"
}

# Function to provide connection improvement recommendations
provide_recommendations() {
    echo -e "\n${BLUE}💡 WebSocket Connection Improvement Recommendations:${NC}"
    
    echo -e "\n${GREEN}Immediate Actions:${NC}"
    echo "1. Monitor connection stability during captioning sessions"
    echo "2. Check for client-side reconnection logic"
    echo "3. Verify network stability between client and server"
    
    echo -e "\n${GREEN}Long-term Improvements:${NC}"
    echo "1. Implement connection health monitoring"
    echo "2. Add automatic reconnection mechanisms"
    echo "3. Implement connection pooling for multiple clients"
    echo "4. Add connection quality metrics"
    
    echo -e "\n${GREEN}Monitoring Commands:${NC}"
    echo "• Real-time WebSocket monitoring: $0 --monitor"
    echo "• Connection status check: $0 --status"
    echo "• Error analysis: $0 --errors"
}

# Function to restart WebSocket services
restart_websocket_services() {
    echo -e "\n${BLUE}🔄 Restarting WebSocket Services:${NC}"
    
    echo "Restarting Docker container to refresh WebSocket connections..."
    docker-compose restart
    
    echo "Waiting for container to fully start..."
    sleep 15
    
    echo "Checking WebSocket status after restart..."
    check_websocket_connections
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -s, --status        Show current WebSocket status only"
    echo "  -e, --errors        Show connection error analysis only"
    echo "  -n, --network       Check network connectivity only"
    echo "  -o, --optimize      Show optimization recommendations"
    echo "  -t, --test          Test WebSocket stability"
    echo "  -r, --restart       Restart WebSocket services"
    echo ""
    echo "Examples:"
    echo "  $0                  # Run full WebSocket analysis"
    echo "  $0 -s               # Show status only"
    echo "  $0 -t               # Test connection stability"
}

# Main execution
main() {
    echo "Starting WebSocket connection analysis..."
    echo ""
    
    check_websocket_connections
    check_connection_errors
    check_network_connectivity
    optimize_websocket_settings
    
    echo -e "\n${BLUE}✅ WebSocket analysis complete!${NC}"
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_usage
        exit 0
        ;;
    -s|--status)
        check_websocket_connections
        exit 0
        ;;
    -e|--errors)
        check_connection_errors
        exit 0
        ;;
    -n|--network)
        check_network_connectivity
        exit 0
        ;;
    -o|--optimize)
        optimize_websocket_settings
        exit 0
        ;;
    -t|--test)
        test_websocket_stability
        exit 0
        ;;
    -r|--restart)
        restart_websocket_services
        exit 0
        ;;
    "")
        main
        ;;
    *)
        echo "Unknown option: $1"
        show_usage
        exit 1
        ;;
esac

# Show recommendations after main execution
if [ "${1:-}" = "" ]; then
    provide_recommendations
fi



