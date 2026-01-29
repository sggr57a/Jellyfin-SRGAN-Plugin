# SRGAN Watchdog Systemd Service Guide

## Overview

The SRGAN watchdog webhook listener is now installed as a systemd service, providing:

- ✅ **Automatic startup** on system boot
- ✅ **Automatic restart** if the service crashes
- ✅ **Background operation** - no need to keep a terminal open
- ✅ **System logging** via journalctl
- ✅ **Easy management** with simple commands

## Installation

The systemd service is installed automatically when you run:

```bash
./scripts/install_all.sh
```

### Manual Installation

If you need to install the service separately:

```bash
sudo ./scripts/install_systemd_watchdog.sh
```

The installation script:
1. Checks for prerequisites (Docker, Python, Flask)
2. Installs Flask if needed
3. Creates the systemd service file
4. Enables the service to start on boot
5. Starts the service immediately
6. Tests the webhook health

## Service Management

### Using the Management Script (Recommended)

A convenient management script is provided:

```bash
./scripts/manage_watchdog.sh [command]
```

**Available commands:**

| Command | Description |
|---------|-------------|
| `status` | Show detailed service status |
| `start` | Start the service |
| `stop` | Stop the service |
| `restart` | Restart the service |
| `logs` | Show live logs (follow mode) |
| `recent` | Show last 50 log entries |
| `enable` | Enable service to start on boot |
| `disable` | Disable service from starting on boot |
| `install` | Install the systemd service |
| `uninstall` | Remove the systemd service |
| `test` | Run webhook connectivity tests |
| `health` | Quick health check |

**Examples:**

```bash
# Check if service is running
./scripts/manage_watchdog.sh status

# View live logs
./scripts/manage_watchdog.sh logs

# Restart after making changes
./scripts/manage_watchdog.sh restart

# Test webhook
./scripts/manage_watchdog.sh health
```

### Using Systemctl Directly

If you prefer direct systemctl commands:

```bash
# Status
sudo systemctl status srgan-watchdog.service

# Start/Stop/Restart
sudo systemctl start srgan-watchdog.service
sudo systemctl stop srgan-watchdog.service
sudo systemctl restart srgan-watchdog.service

# Enable/Disable auto-start on boot
sudo systemctl enable srgan-watchdog.service
sudo systemctl disable srgan-watchdog.service

# Check if running
systemctl is-active srgan-watchdog.service

# Check if enabled for boot
systemctl is-enabled srgan-watchdog.service
```

## Viewing Logs

### Using the Management Script

```bash
# Live logs (follow mode)
./scripts/manage_watchdog.sh logs

# Recent logs (last 50 lines)
./scripts/manage_watchdog.sh recent
```

### Using Journalctl Directly

```bash
# Live logs (follow mode)
sudo journalctl -u srgan-watchdog.service -f

# Last 100 lines
sudo journalctl -u srgan-watchdog.service -n 100

# Today's logs
sudo journalctl -u srgan-watchdog.service --since today

# Logs since boot
sudo journalctl -u srgan-watchdog.service -b

# Logs with full timestamps
sudo journalctl -u srgan-watchdog.service -o short-precise

# Filter by time
sudo journalctl -u srgan-watchdog.service --since "2024-01-01 10:00:00"
sudo journalctl -u srgan-watchdog.service --since "1 hour ago"
```

## Service Details

### Service Configuration

- **Service name**: `srgan-watchdog.service`
- **Service file**: `/etc/systemd/system/srgan-watchdog.service`
- **Runs as**: Current user (not root)
- **Working directory**: Project root directory
- **Python**: Uses system Python 3
- **Port**: 5000 (Flask default)

### Service Behavior

- **Start order**: After network is online and Docker service
- **Auto-restart**: Yes, with 10-second delay
- **Restart policy**: Always (even on clean exit)
- **Logging**: System journal (journalctl)
- **Security**: Runs as non-root user with NoNewPrivileges

### Environment Variables

The service sets these environment variables:

```bash
UPSCALED_DIR=/data/upscaled           # Output directory
SRGAN_QUEUE_FILE=./cache/queue.jsonl  # Queue file location
PYTHONUNBUFFERED=1                    # Immediate output to logs
```

You can customize these by editing the service file:

```bash
sudo systemctl edit srgan-watchdog.service
```

## Common Tasks

### Check Service Status

```bash
# Quick status
./scripts/manage_watchdog.sh status

# Or with systemctl
sudo systemctl status srgan-watchdog.service
```

**Example output:**
```
● srgan-watchdog.service - SRGAN Watchdog - Jellyfin Webhook Listener
     Loaded: loaded (/etc/systemd/system/srgan-watchdog.service; enabled)
     Active: active (running) since Mon 2024-01-29 10:15:30 UTC; 2h ago
   Main PID: 12345 (python3)
      Tasks: 2 (limit: 4915)
     Memory: 45.2M
     CGroup: /system.slice/srgan-watchdog.service
             └─12345 /usr/bin/python3 /path/to/scripts/watchdog.py
```

### Restart After Configuration Changes

```bash
./scripts/manage_watchdog.sh restart
```

### View Recent Errors

```bash
./scripts/manage_watchdog.sh recent | grep ERROR
```

### Test Webhook

```bash
# Quick health check
./scripts/manage_watchdog.sh health

# Full test suite
./scripts/manage_watchdog.sh test
```

### Stop Service Temporarily

```bash
./scripts/manage_watchdog.sh stop
```

### Disable Auto-Start

If you want to manage the watchdog manually instead:

```bash
# Disable auto-start
./scripts/manage_watchdog.sh disable

# Stop the service
./scripts/manage_watchdog.sh stop

# Now run manually when needed
python3 scripts/watchdog.py
```

## Troubleshooting

### Service Won't Start

**Check logs for errors:**
```bash
./scripts/manage_watchdog.sh recent
```

**Common issues:**

1. **Flask not installed:**
   ```bash
   pip3 install flask requests
   sudo systemctl restart srgan-watchdog.service
   ```

2. **Port 5000 in use:**
   ```bash
   # Check what's using port 5000
   lsof -i :5000

   # Kill the process or change the port
   ```

3. **Permissions error:**
   ```bash
   # Ensure cache directory exists and is writable
   mkdir -p ./cache
   chmod 755 ./cache
   ```

### Service Keeps Restarting

**Monitor the restart cycle:**
```bash
./scripts/manage_watchdog.sh logs
```

**Check for:**
- Import errors (missing Python packages)
- Port conflicts
- File permission issues
- Docker not running

### Webhook Not Responding

**Check if service is actually running:**
```bash
./scripts/manage_watchdog.sh status
```

**Test the endpoint:**
```bash
curl http://localhost:5000/health
```

**Check firewall:**
```bash
# Ubuntu
sudo ufw status
sudo ufw allow 5000

# CentOS/RHEL
sudo firewall-cmd --list-ports
sudo firewall-cmd --add-port=5000/tcp --permanent
sudo firewall-cmd --reload
```

### Service Running But Not Processing Jobs

**Check Docker container:**
```bash
docker compose ps
docker compose logs srgan-upscaler
```

**Check queue file:**
```bash
cat ./cache/queue.jsonl
```

**Check file paths:**
- Ensure paths in webhook match filesystem
- Check volume mounts in docker-compose.yml

## Uninstalling the Service

### Complete Removal

```bash
./scripts/manage_watchdog.sh uninstall
```

This will:
1. Stop the service
2. Disable it from starting on boot
3. Remove the service file
4. Reload systemd

### Manual Removal

```bash
# Stop and disable
sudo systemctl stop srgan-watchdog.service
sudo systemctl disable srgan-watchdog.service

# Remove service file
sudo rm /etc/systemd/system/srgan-watchdog.service

# Reload systemd
sudo systemctl daemon-reload
```

## Comparison: Systemd vs Manual

| Feature | Systemd Service | Manual Start |
|---------|----------------|--------------|
| Auto-start on boot | ✅ Yes | ❌ No |
| Auto-restart on crash | ✅ Yes | ❌ No |
| Background operation | ✅ Yes | ⚠️ Requires nohup |
| Logging | ✅ System journal | ⚠️ Manual log file |
| Management | ✅ Simple commands | ⚠️ Manual process management |
| Port conflict detection | ✅ Systemd handles | ❌ Manual check needed |
| **Recommended for** | Production | Development/Testing |

## Best Practices

1. **Use systemd for production** - Set it and forget it
2. **Monitor logs regularly** - Check for errors with `./scripts/manage_watchdog.sh recent`
3. **Test after updates** - Run `./scripts/manage_watchdog.sh test` after changes
4. **Keep service enabled** - Ensure it starts after reboots
5. **Check status periodically** - Use monitoring tools or cron jobs

## Advanced Configuration

### Customizing the Service

Edit the service configuration:

```bash
sudo systemctl edit srgan-watchdog.service
```

Add overrides (example):

```ini
[Service]
# Change environment variables
Environment="UPSCALED_DIR=/custom/path"
Environment="SRGAN_QUEUE_FILE=/custom/queue.jsonl"

# Increase restart delay
RestartSec=30

# Change restart policy
Restart=on-failure
```

Save and reload:

```bash
sudo systemctl daemon-reload
sudo systemctl restart srgan-watchdog.service
```

### Running Multiple Instances

If you need multiple watchdog instances:

1. Copy the service file with a new name
2. Change the port in the configuration
3. Enable and start the new service

### Monitoring with External Tools

The service can be monitored with:
- Nagios
- Prometheus + node_exporter
- Zabbix
- Custom monitoring scripts

Example health check for monitoring:

```bash
#!/bin/bash
if curl -s http://localhost:5000/health > /dev/null; then
  echo "OK"
  exit 0
else
  echo "CRITICAL"
  exit 2
fi
```

## Quick Reference Card

```
╔═══════════════════════════════════════════════════════════════╗
║       SRGAN WATCHDOG SYSTEMD SERVICE QUICK REFERENCE          ║
╠═══════════════════════════════════════════════════════════════╣
║ Status:    ./scripts/manage_watchdog.sh status               ║
║ Logs:      ./scripts/manage_watchdog.sh logs                 ║
║ Restart:   ./scripts/manage_watchdog.sh restart              ║
║ Test:      ./scripts/manage_watchdog.sh health               ║
╠═══════════════════════════════════════════════════════════════╣
║ Service:   srgan-watchdog.service                            ║
║ Port:      5000                                               ║
║ Endpoint:  http://localhost:5000/upscale-trigger            ║
║ Health:    http://localhost:5000/health                      ║
╠═══════════════════════════════════════════════════════════════╣
║ Install:   sudo ./scripts/install_systemd_watchdog.sh       ║
║ Manage:    ./scripts/manage_watchdog.sh [command]           ║
╚═══════════════════════════════════════════════════════════════╝
```

## See Also

- **[README.md](README.md)** - Project overview
- **[GETTING_STARTED.md](GETTING_STARTED.md)** - Installation guide
- **[WEBHOOK_SETUP.md](WEBHOOK_SETUP.md)** - Webhook configuration
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Problem solving
- **[scripts/README.md](scripts/README.md)** - Scripts documentation
- **[DOCUMENTATION.md](DOCUMENTATION.md)** - Complete documentation index
- [systemd documentation](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
