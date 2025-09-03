#!/bin/bash

# Docker Audio Setup Script
# This script configures PulseAudio and ALSA for proper audio support in Docker

set -e

echo "Setting up audio configuration for Docker..."

# Create necessary directories
mkdir -p /etc/pulse
mkdir -p /root/.config/pulse
mkdir -p /tmp/pulse-audio

# Create PulseAudio configuration
cat > /etc/pulse/client.conf << 'EOF'
# Connect to the host's PulseAudio server
default-server = unix:/tmp/pulse-socket

# Prevent a PulseAudio server running in the container
autospawn = no
daemon-binary = /bin/true

# Prevent the use of shared memory
enable-shm = false
EOF

# Skip ALSA configuration - let Azure Speech SDK use defaults
echo "Skipping ALSA configuration - using system defaults"

# Create a simple audio test script
cat > /usr/local/bin/test-audio << 'EOF'
#!/bin/bash
echo "Testing audio configuration..."

echo "Available ALSA cards:"
aplay -l 2>/dev/null || echo "No ALSA cards found"

echo "Available ALSA capture devices:"
arecord -l 2>/dev/null || echo "No ALSA capture devices found"

echo "Testing PulseAudio connection:"
pulseaudio --check -v 2>/dev/null && echo "PulseAudio is running" || echo "PulseAudio not running"

echo "Audio configuration test complete."
EOF

chmod +x /usr/local/bin/test-audio

# Create audio initialization script
cat > /usr/local/bin/init-audio << 'EOF'
#!/bin/bash

# Initialize audio for the container
echo "Initializing audio..."

# Set audio environment variables
export PULSE_RUNTIME_PATH=/tmp/pulse-audio
export PULSE_STATE_PATH=/tmp/pulse-audio
export PULSE_CLIENTCONFIG=/etc/pulse/client.conf

# Create audio group if it doesn't exist
groupadd -f audio

# Set permissions for audio devices
if [ -d /dev/snd ]; then
    chmod 666 /dev/snd/* 2>/dev/null || true
    chgrp audio /dev/snd/* 2>/dev/null || true
fi

echo "Audio initialization complete."
EOF

chmod +x /usr/local/bin/init-audio

echo "Audio configuration setup complete!" 