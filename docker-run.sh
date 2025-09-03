#!/bin/bash

# Docker run script for Caption Stable Application
# This script helps you run the application in a Docker container

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Caption Stable Docker Setup${NC}"
echo "================================"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Error: Docker Compose is not installed. Please install Docker Compose first.${NC}"
    exit 1
fi

# Check if .env file exists, if not create a template
if [ ! -f .env ]; then
    echo -e "${YELLOW}Creating .env template file...${NC}"
    cat > .env << EOF
# Azure Speech Services Configuration
AZURE_SPEECH_KEY=your_azure_speech_key_here
AZURE_SPEECH_REGION=eastus

# Application Configuration
DEBUG_MODE=false
EOF
    echo -e "${YELLOW}Please edit .env file and add your Azure Speech Services key${NC}"
    echo -e "${YELLOW}You can get your key from: https://portal.azure.com${NC}"
    exit 1
fi

# Load environment variables
source .env

# Check if Azure Speech Key is set
if [ -z "$AZURE_SPEECH_KEY" ] || [ "$AZURE_SPEECH_KEY" = "your_azure_speech_key_here" ]; then
    echo -e "${RED}Error: AZURE_SPEECH_KEY is not set in .env file${NC}"
    echo -e "${YELLOW}Please edit .env file and add your Azure Speech Services key${NC}"
    exit 1
fi

# Create logs directory if it doesn't exist
mkdir -p logs

echo -e "${GREEN}Building and starting the application...${NC}"

# Build and run with docker-compose
docker-compose up --build -d

echo -e "${GREEN}Application is starting...${NC}"
echo -e "${GREEN}You can access the application at: http://localhost:8000${NC}"
echo -e "${GREEN}Dashboard: http://localhost:8000/dashboard${NC}"
echo -e "${GREEN}User view: http://localhost:8000/user${NC}"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo -e "  View logs: ${GREEN}docker-compose logs -f${NC}"
echo -e "  Stop app:  ${GREEN}docker-compose down${NC}"
echo -e "  Restart:   ${GREEN}docker-compose restart${NC}"
echo ""
echo -e "${GREEN}Container is running in the background.${NC}" 