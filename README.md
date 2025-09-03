# Caption3 - Real-time Speech Captioning System

A real-time speech captioning system that provides live captions with translation support for multiple languages.

## Features

- Real-time speech recognition and captioning
- Multi-language translation support (English, Spanish, French, German, Chinese, Japanese, Russian, Arabic)
- Web-based dashboard for configuration
- User view with language selection
- Production view for broadcasting
- Custom phrase and spelling correction support
- Scheduled recognition sessions
- Audio device configuration

## System Requirements

- Python 3.8 or higher
- macOS, Windows, or Linux
- Microphone or audio input device
- Azure Speech Service subscription

## Installation

### 1. Extract the Package

```bash
unzip caption3-app.zip
cd caption3-app
```

### 2. Set Up Python Environment

```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
# On macOS/Linux:
source venv/bin/activate
# On Windows:
venv\Scripts\activate
```

### 3. Install Dependencies

```bash
pip install -r requirements.txt
```

### 4. Configure Azure Speech Service

1. Get your Azure Speech Service key from the Azure portal
2. Edit the `.env` file and add your Azure Speech key:
   ```
   AZURE_SPEECH_KEY=your_azure_speech_key_here
   AZURE_SERVICE_REGION=eastus
   ```

### 5. Configure Admin Credentials

Edit the `launch.sh` (macOS/Linux) or `launch.bat` (Windows) file and update:
- `ADMIN_USERNAME` - Admin username for dashboard access
- `ADMIN_PASSWORD` - Admin password for dashboard access
- `WEBSOCKET_TOKEN` - Token for WebSocket connections

## Usage

### Quick Start

```bash
# Make launch script executable (macOS/Linux only)
chmod +x launch.sh

# Run the application
./launch.sh
```

### Manual Start

```bash
# Activate virtual environment
source venv/bin/activate

# Set environment variables
export AZURE_SPEECH_KEY="your_azure_speech_key_here"
export ADMIN_USERNAME="admin"
export ADMIN_PASSWORD="your_password"
export WEBSOCKET_TOKEN="your_token"

# Run the application
python captionStable.py
```

### Access the Application

1. **Dashboard**: http://localhost:8000/dashboard
   - Username: admin
   - Password: (as set in launch script)

2. **User View**: http://localhost:8000/user
   - Public access for viewing captions

3. **Setup**: http://localhost:8000/setup
   - Configure audio devices and Azure key

## Configuration Files

- `config.json` - Main application configuration
- `dictionary.json` - Custom phrases, spelling corrections, and supported languages
- `user_settings.json` - User view display settings
- `schedule.json` - Scheduled recognition sessions

## Troubleshooting

### Common Issues

1. **Audio Device Not Found**
   - Visit http://localhost:8000/setup to configure audio devices
   - Ensure microphone permissions are granted

2. **Azure Speech Service Error**
   - Verify your Azure Speech key is correct
   - Check your Azure subscription status
   - Ensure the service region is correct

3. **Port Already in Use**
   - The app uses port 8000 by default
   - Stop other applications using this port
   - Or modify the port in `captionStable.py`

### Logs

Check `caption_log.txt` for detailed application logs and error messages.

## File Structure

```
caption3-app/
├── captionStable.py          # Main application
├── requirements.txt          # Python dependencies
├── config.json              # Application configuration
├── dictionary.json          # Custom phrases and languages
├── user_settings.json       # User view settings
├── schedule.json            # Scheduled sessions
├── .env                     # Environment variables
├── launch.sh                # Launch script (macOS/Linux)
├── launch.bat               # Launch script (Windows)
├── README.md                # This file
├── *.html                   # Web interface files
└── venv/                    # Python virtual environment
```

## Support

For issues or questions, check the logs in `caption_log.txt` or review the configuration files. 