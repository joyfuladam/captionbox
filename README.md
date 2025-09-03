# Caption3B - Production Captioning System

A comprehensive real-time captioning application with Docker support, audio device management, and advanced monitoring capabilities.

## 🚀 Features

- **Real-time Captioning**: WebSocket-based live captioning with Azure Speech SDK
- **Docker Support**: Complete containerization with Docker Compose
- **Audio Management**: Advanced audio device configuration and troubleshooting
- **Monitoring Tools**: Comprehensive monitoring and diagnostic scripts
- **WebSocket Integration**: Stable real-time communication for caption streaming
- **Log Management**: Automated log rotation and analysis tools
- **Health Checks**: Built-in health monitoring and restart capabilities

## 📁 Project Structure

```
caption3b/
├── captionStable.py              # Main application file
├── captionStable_docker.py       # Docker-specific application variant
├── docker-compose.yml            # Docker Compose configuration
├── Dockerfile                    # Docker image definition
├── config.json                   # Application configuration
├── dictionary.json               # Caption dictionary settings
├── user_settings.json            # User preferences
├── schedule.json                 # Schedule configuration
├── requirements.txt              # Python dependencies
├── audio-fix.sh                  # Audio device configuration script
├── monitor_captions.sh           # Comprehensive monitoring dashboard
├── watch_logs.sh                 # Real-time log monitoring
├── diagnose_hangs.sh             # Caption pause diagnosis tool
├── fix_websocket_connections.sh  # WebSocket connection optimization
├── websocket_monitor.sh          # WebSocket connection monitoring
├── rotate_logs.sh                # Log rotation and management
└── README.md                     # This file
```

## 🛠️ Setup and Installation

### Prerequisites
- Docker and Docker Compose
- Azure Speech Service account
- Linux system with PulseAudio/ALSA support

### Environment Configuration
Create a `.env` file with your Azure credentials:
```bash
AZURE_SPEECH_KEY=your_azure_speech_key
AZURE_SERVICE_REGION=eastus
```

### Quick Start
1. **Apply Audio Fix** (required for audio device detection):
   ```bash
   ./audio-fix.sh
   ```

2. **Launch Application**:
   ```bash
   docker-compose up -d
   ```

3. **Monitor System**:
   ```bash
   ./monitor_captions.sh
   ```

## 🔧 Key Components

### Audio Management
- **audio-fix.sh**: Configures PulseAudio and ALSA for Docker containers
- **docker-audio-setup.sh**: Sets up audio within Docker containers
- **asound.conf**: ALSA configuration for audio devices

### Monitoring and Diagnostics
- **monitor_captions.sh**: Comprehensive monitoring dashboard
- **watch_logs.sh**: Real-time log monitoring with activity detection
- **diagnose_hangs.sh**: Identifies common causes of caption pauses
- **fix_websocket_connections.sh**: WebSocket connection optimization
- **websocket_monitor.sh**: Real-time WebSocket monitoring

### Log Management
- **rotate_logs.sh**: Automated log rotation (50MB threshold, 3 backups)
- **CAPTION_PAUSE_ANALYSIS.md**: Analysis of common caption pause causes

## 🐳 Docker Configuration

The application uses Docker Compose with the following key features:
- **Network Mode**: Host networking for audio device access
- **Volume Mounts**: Configuration files, logs, and audio device access
- **Health Checks**: Built-in health monitoring
- **Environment Variables**: Azure credentials and system configuration
- **User Mapping**: Proper user/group mapping for audio access

## 📊 Monitoring and Troubleshooting

### Common Issues and Solutions

1. **Audio Devices Not Detected**:
   ```bash
   ./audio-fix.sh
   docker-compose restart
   ```

2. **Caption Pauses/Hangs**:
   ```bash
   ./diagnose_hangs.sh
   ./monitor_captions.sh
   ```

3. **WebSocket Connection Issues**:
   ```bash
   ./fix_websocket_connections.sh
   ./websocket_monitor.sh
   ```

4. **Log File Management**:
   ```bash
   ./rotate_logs.sh
   ```

### Monitoring Commands
- `./monitor_captions.sh` - Full system monitoring dashboard
- `./watch_logs.sh` - Real-time log monitoring
- `docker logs caption-stable -f` - Docker container logs
- `docker exec caption-stable ps aux` - Container process monitoring

## 🔐 Security Features

- Basic authentication for admin endpoints
- WebSocket token authentication
- Environment variable protection for sensitive data
- Docker security best practices

## 📈 Performance Optimization

- WebSocket connection pooling
- Audio buffer optimization
- Log rotation to prevent disk space issues
- Health check monitoring for automatic recovery

## 🚨 Production Notes

This system has been optimized for production use with:
- Comprehensive error handling and recovery
- Detailed logging and monitoring
- Audio device stability fixes
- WebSocket connection optimization
- Automated maintenance tools

## 📝 License

This project is part of the Northway Technologies captioning system.

## 🤝 Support

For technical support and troubleshooting, refer to the monitoring tools and diagnostic scripts included in this repository.

---

**Last Updated**: September 3, 2024  
**Version**: Caption3B Production  
**Status**: Production Ready