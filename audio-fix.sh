#!/bin/bash

# Audio Fix Script for Caption3B
# This script fixes audio device detection issues after VM reboots

set -e

echo "Starting audio device fix process..."

# Wait for system to fully boot
sleep 10

# Function to check if PulseAudio is running
check_pulseaudio() {
    if pulseaudio --check 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to check if audio devices are properly detected
check_audio_devices() {
    local sources=$(pactl list sources short 2>/dev/null | grep -c "alsa_input" || echo "0")
    local sinks=$(pactl list sinks short 2>/dev/null | grep -c "alsa_output" || echo "0")
    
    # Convert to integers for comparison
    sources=$(echo "$sources" | tr -d ' ')
    sinks=$(echo "$sinks" | tr -d ' ')
    
    if [ "$sources" -gt 0 ] && [ "$sinks" -gt 0 ]; then
        return 0
    else
        return 1
    fi
}

# Function to restart PulseAudio
restart_pulseaudio() {
    echo "Restarting PulseAudio..."
    
    # Kill PulseAudio if running
    if check_pulseaudio; then
        pulseaudio --kill
        sleep 2
    fi
    
    # Start PulseAudio
    pulseaudio --start
    sleep 3
    
    echo "PulseAudio restarted"
}

# Function to load ALSA devices into PulseAudio
load_alsa_devices() {
    echo "Loading ALSA devices into PulseAudio..."
    
    # Stop Docker container to free up audio devices
    if docker ps | grep -q caption-stable; then
        echo "Stopping Docker container to free audio devices..."
        docker stop caption-stable
        sleep 2
    fi
    
    # Check if ALSA sink is already loaded
    if ! pactl list sinks short | grep -q "alsa_output.hw_1_0"; then
        pactl load-module module-alsa-sink device=hw:1,0 2>/dev/null || echo "ALSA sink already loaded or failed"
    else
        echo "ALSA sink already loaded"
    fi
    
    # Check if ALSA source is already loaded
    if ! pactl list sources short | grep -q "alsa_input.hw_1_0"; then
        pactl load-module module-alsa-source device=hw:1,0 2>/dev/null || echo "ALSA source already loaded or failed"
    else
        echo "ALSA source already loaded"
    fi
    
    sleep 2
    echo "ALSA devices loaded"
}

# Function to restart Docker container
restart_docker() {
    echo "Restarting Docker container..."
    
    cd /home/nwtech/caption3b
    
    # Stop container if running
    if docker ps | grep -q caption-stable; then
        docker stop caption-stable
        sleep 2
    fi
    
    # Start container
    docker-compose up -d
    sleep 5
    
    echo "Docker container restarted"
}

# Main execution
echo "Checking audio device status..."

# Check if PulseAudio is running and has proper devices
if ! check_pulseaudio || ! check_audio_devices; then
    echo "Audio devices not properly detected, fixing..."
    restart_pulseaudio
    
    # Wait a bit and check again
    sleep 5
    if ! check_audio_devices; then
        echo "Audio devices still not detected after PulseAudio restart, trying to load ALSA devices manually..."
        load_alsa_devices
        
        # Check again after loading devices
        sleep 3
        if ! check_audio_devices; then
            echo "Audio devices still not detected after manual ALSA device loading"
            exit 1
        fi
    fi
fi

echo "Audio devices are properly detected"

# Check if Docker container needs restarting
if docker ps | grep -q caption-stable; then
    echo "Docker container is running, checking audio access..."
    
    # Test if container can access audio devices
    if ! docker exec caption-stable pactl list sources short 2>/dev/null | grep -q "alsa_input"; then
        echo "Container cannot access audio devices, restarting..."
        restart_docker
    else
        echo "Container has proper audio access"
    fi
else
    echo "Docker container not running, starting..."
    restart_docker
fi

echo "Audio fix process completed successfully"
echo "Audio devices:"
pactl list sources short
echo "Docker container status:"
docker ps | grep caption-stable || echo "Container not found" 