#!/bin/bash

# Caption3B Backup Restoration Script
# This script automates the restoration of the Caption3B stable build

set -e  # Exit on any error

echo "🎯 Caption3B Stable Build Restoration Script"
echo "=============================================="
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "❌ This script should not be run as root"
   exit 1
fi

# Check prerequisites
echo "🔍 Checking prerequisites..."

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

echo "✅ Prerequisites check passed"

# Check if .env file exists
if [ ! -f .env ]; then
    echo ""
    echo "📝 Creating .env file..."
    echo "Please provide your Azure Speech Services credentials:"
    echo ""
    
    read -p "Enter your Azure Speech Key: " AZURE_SPEECH_KEY
    read -p "Enter your Azure Speech Region (e.g., eastus): " AZURE_SPEECH_REGION
    
    # Create .env file
    cat > .env << EOF
AZURE_SPEECH_KEY=$AZURE_SPEECH_KEY
AZURE_SPEECH_REGION=$AZURE_SPEECH_REGION
DEBUG_MODE=false
ADMIN_USERNAME=admin
ADMIN_PASSWORD=Northway12121
WEBSOCKET_TOKEN=Northway12121
EOF
    
    echo "✅ .env file created"
else
    echo "✅ .env file already exists"
fi

# Check if running in a VM with audio passthrough
echo ""
echo "🔊 Audio Configuration Check"
echo "============================"

# Check for audio devices
if lspci | grep -i audio > /dev/null; then
    echo "✅ Audio devices detected:"
    lspci | grep -i audio
else
    echo "⚠️  No audio devices detected. This might be expected in some environments."
fi

# Check ALSA
if command -v aplay &> /dev/null; then
    echo "✅ ALSA is available"
    echo "Available audio devices:"
    aplay -l 2>/dev/null || echo "No playback devices found"
else
    echo "⚠️  ALSA not available"
fi

echo ""
echo "🐳 Building and starting Docker containers..."
echo "This may take several minutes on first run..."

# Build and start containers
docker-compose down 2>/dev/null || true
docker-compose build --no-cache
docker-compose up -d

echo ""
echo "⏳ Waiting for containers to start..."
sleep 10

# Check if containers are running
if docker-compose ps | grep -q "Up"; then
    echo "✅ Containers are running"
else
    echo "❌ Containers failed to start"
    echo "Check logs with: docker-compose logs"
    exit 1
fi

# Wait for application to be ready
echo "⏳ Waiting for application to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:8000/health > /dev/null 2>&1; then
        echo "✅ Application is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Application failed to start within 30 seconds"
        echo "Check logs with: docker logs caption-stable"
        exit 1
    fi
    sleep 1
done

echo ""
echo "🎉 Caption3B Stable Build Successfully Restored!"
echo "================================================"
echo ""
echo "🌐 Access your application:"
echo "   Production View: http://localhost:8000/"
echo "   User View: http://localhost:8000/user"
echo "   Dashboard: http://localhost:8000/dashboard"
echo ""
echo "🔑 Default credentials:"
echo "   Username: admin"
echo "   Password: Northway12121"
echo ""
echo "📋 Useful commands:"
echo "   View logs: docker logs caption-stable"
echo "   Stop application: docker-compose down"
echo "   Restart application: docker-compose restart"
echo "   Update application: docker-compose pull && docker-compose up -d"
echo ""
echo "🔧 To start speech recognition:"
echo "   1. Open the Dashboard: http://localhost:8000/dashboard"
echo "   2. Login with admin/Northway12121"
echo "   3. Click 'Start Recognition'"
echo "   4. Speak into your microphone"
echo ""
echo "📖 For detailed documentation, see: BACKUP_README.md"
echo ""
echo "✅ Restoration complete!" 