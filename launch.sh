#!/bin/bash

# Navigate to project directory
cd /Users/adamf/projects/captioning

# Activate virtual environment
source venv/bin/activate

# Set environment variables (modify these as needed)
export AZURE_SPEECH_KEY="your_azure_speech_key_here"
export ADMIN_USERNAME="admin"
export ADMIN_PASSWORD="Northway12121"
export WEBSOCKET_TOKEN="Northway12121"

# Launch the app
echo "Starting Captioning App..."
python captionStable.py 