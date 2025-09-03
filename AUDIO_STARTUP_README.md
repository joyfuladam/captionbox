# Audio Startup Scripts for Caption3B

This directory contains scripts to automatically fix audio device detection issues after VM reboots.

## Problem
After rebooting the VM, PulseAudio sometimes doesn't properly detect hardware audio devices, and the Docker container loses access to the microphone. This results in no audio input being available for the captioning application.

## Solution
Two automated solutions are provided:

### Option 1: Systemd Service (Recommended)
A systemd service that runs automatically after boot to fix audio devices.

**Files:**
- `audio-fix.service` - Systemd service definition
- `audio-fix.sh` - Main script that fixes audio devices

**Setup (already done):**
```bash
sudo cp audio-fix.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable audio-fix.service
```

**Status:**
```bash
# Check if service is enabled
sudo systemctl is-enabled audio-fix.service

# Check service status
sudo systemctl status audio-fix.service

# View logs
sudo journalctl -u audio-fix.service
```

### Option 2: Cron Job (Alternative)
A cron job that runs after each reboot.

**Files:**
- `setup-cron.sh` - Script to set up the cron job

**Setup:**
```bash
./setup-cron.sh
```

**View cron jobs:**
```bash
crontab -l
```

## Manual Usage
You can also run the audio fix script manually:

```bash
./audio-fix.sh
```

## What the Script Does
1. **Checks audio device status** - Verifies if PulseAudio is running and has proper devices
2. **Restarts PulseAudio** - If devices aren't detected, kills and restarts PulseAudio
3. **Restarts Docker container** - If the container can't access audio devices, restarts it
4. **Verifies success** - Confirms that both host and container have proper audio access

## Logs
- Systemd service logs: `sudo journalctl -u audio-fix.service`
- Cron job logs: `/home/nwtech/caption3b/logs/audio-fix.log`

## Troubleshooting
If audio devices still aren't working after reboot:

1. **Check service status:**
   ```bash
   sudo systemctl status audio-fix.service
   ```

2. **Run manually:**
   ```bash
   ./audio-fix.sh
   ```

3. **Check audio devices:**
   ```bash
   pactl list sources short
   docker exec caption-stable pactl list sources short
   ```

4. **Restart everything manually:**
   ```bash
   pulseaudio --kill
   pulseaudio --start
   docker stop caption-stable
   docker-compose up -d
   ```

## Files Created
- `audio-fix.service` - Systemd service file
- `audio-fix.sh` - Main audio fix script
- `setup-cron.sh` - Cron job setup script
- `AUDIO_STARTUP_README.md` - This documentation

## Notes
- The systemd service is already enabled and will run automatically on boot
- The script includes safety checks to avoid unnecessary restarts
- Both host system and Docker container audio access are verified
- Logs are generated for troubleshooting 