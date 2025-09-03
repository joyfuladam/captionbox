# Caption3B Monitoring Guide

This guide explains how to monitor the captioning process and identify causes of pauses, hangs, and performance issues.

## 🚨 Critical Issues Identified

Based on the current diagnosis:
- **System appears to be hung**: No log activity for over 39 days
- **Low disk space**: 93% disk usage (critical)
- **High error count**: 17 errors detected
- **Container health**: Currently healthy but may need restart

## 📊 Monitoring Tools Available

### 1. Quick Status Check
```bash
./diagnose_hangs.sh
```
**Use this when:** You suspect the system is hanging or experiencing issues
**What it shows:** Container status, log gaps, errors, system resources, audio devices, network connectivity

### 2. Real-time Log Monitoring
```bash
./watch_logs.sh
```
**Use this when:** You want to watch logs in real-time to catch issues as they happen
**What it shows:** Live log entries with color-coded highlighting and activity gap warnings

### 3. Full Monitoring Dashboard
```bash
./monitor_captions.sh
```
**Use this when:** You want comprehensive monitoring with interactive features
**What it shows:** Full system overview with options for real-time monitoring

### 4. Docker Container Logs
```bash
docker logs caption-stable -f
```
**Use this when:** You want to see the raw Docker container logs
**What it shows:** All container output including startup messages and errors

## 🔍 What to Look For

### Signs of Pauses/Hangs

1. **Log Activity Gaps**
   - No log entries for >30 seconds = Warning
   - No log entries for >5 minutes = Critical (system likely hung)

2. **Error Patterns**
   - `SPXERR_START_RECOGNIZING_INVALID_STATE_TRANSITION` = Azure Speech SDK issues
   - `WebSocket error: 1001` = Connection problems
   - `Exception` or `Traceback` = Python errors

3. **Resource Issues**
   - CPU >80% = High load
   - Memory >80% = Memory pressure
   - Disk >90% = Critical (can cause hangs)

4. **Container Health**
   - Status: `unhealthy` = Container has issues
   - Status: `starting` = Container is still initializing

### Common Causes of Hangs

1. **Audio Device Issues**
   - PulseAudio not running
   - ALSA device conflicts
   - Permission problems

2. **Network Problems**
   - WebSocket connection drops
   - Azure Speech service timeouts
   - Port conflicts

3. **Resource Exhaustion**
   - Low disk space
   - High memory usage
   - CPU overload

4. **Azure Speech SDK Issues**
   - Invalid state transitions
   - Service timeouts
   - Authentication problems

## 🛠️ Troubleshooting Steps

### When System Appears Hung

1. **Check container status**
   ```bash
   docker ps
   ```

2. **Run diagnosis**
   ```bash
   ./diagnose_hangs.sh
   ```

3. **Check real-time logs**
   ```bash
   ./watch_logs.sh
   ```

4. **Restart if necessary**
   ```bash
   docker restart caption-stable
   ```

### When Audio Issues Occur

1. **Run audio fix**
   ```bash
   ./audio-fix.sh
   ```

2. **Check audio devices**
   ```bash
   ./diagnose_hangs.sh -a
   ```

3. **Restart container**
   ```bash
   docker-compose restart
   ```

### When Performance Degrades

1. **Monitor resources**
   ```bash
   ./monitor_captions.sh -s
   ```

2. **Check for errors**
   ```bash
   ./diagnose_hangs.sh -e
   ```

3. **Restart if needed**
   ```bash
   docker-compose restart
   ```

## 📈 Performance Monitoring

### Key Metrics to Watch

- **Response Time**: Health endpoint should respond in <1 second
- **Log Frequency**: Should see regular activity during captioning
- **Resource Usage**: CPU <80%, Memory <80%, Disk <90%
- **Error Rate**: <5 errors per hour during normal operation

### Normal Operation Patterns

- Regular log entries every few seconds during captioning
- WebSocket connections maintained
- Audio devices accessible
- Azure Speech service responding

## 🚀 Proactive Monitoring

### Daily Checks
```bash
./diagnose_hangs.sh -s
```

### During Captioning Sessions
```bash
./watch_logs.sh
```

### Weekly Deep Dive
```bash
./monitor_captions.sh
```

## 📞 Emergency Procedures

### System Completely Unresponsive
1. Force stop container: `docker kill caption-stable`
2. Check system resources: `htop` or `top`
3. Restart container: `docker-compose up -d`
4. Run diagnosis: `./diagnose_hangs.sh`

### Audio Not Working
1. Run audio fix: `./audio-fix.sh`
2. Restart container: `docker-compose restart`
3. Test audio: `./diagnose_hangs.sh -a`

### Persistent Issues
1. Check logs for patterns: `grep ERROR caption_log.txt | tail -20`
2. Review system resources: `df -h`, `free -h`
3. Consider full restart: `docker-compose down && docker-compose up -d`

## 🔧 Maintenance

### Log Rotation
- Monitor log file sizes
- Consider log rotation if files exceed 100MB
- Archive old logs if needed

### System Updates
- Keep Docker updated
- Monitor for Azure Speech SDK updates
- Check system package updates

### Backup Verification
- Run `./verify_backup.sh` regularly
- Test restore procedures
- Monitor backup file integrity

## 📚 Additional Resources

- **Docker logs**: `docker logs caption-stable --help`
- **System monitoring**: `htop`, `iotop`, `nethogs`
- **Network debugging**: `netstat`, `ss`, `tcpdump`
- **Audio debugging**: `pactl`, `aplay`, `arecord`

---

**Remember**: The key to preventing hangs is proactive monitoring. Use these tools regularly to catch issues before they become critical problems.



