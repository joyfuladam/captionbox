@echo off

REM Navigate to project directory
cd /d "%~dp0"

REM Activate virtual environment
call venv\Scripts\activate.bat

REM Set environment variables (modify these as needed)
set AZURE_SPEECH_KEY=your_azure_speech_key_here
set ADMIN_USERNAME=admin
set ADMIN_PASSWORD=Northway12121
set WEBSOCKET_TOKEN=Northway12121

REM Launch the app
echo Starting Captioning App...
python captionStable.py

pause 