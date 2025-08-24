# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Discord Auto-Updater system for Debian/Ubuntu Linux systems. Since Discord doesn't provide an official APT repository, this tool automatically updates Discord to keep users on the latest version without manual intervention.

## Architecture

The system consists of five main components:

- **discord-auto-updater.sh**: Main bash script that handles version checking, downloading, and installation
- **install.sh**: Installation script that sets up the entire system
- **discord-updater.conf**: Configuration file template with default settings
- **discord-auto-updater.service**: Systemd service file for one-shot execution
- **discord-auto-updater.timer**: Systemd timer for daily automated checks

## Common Commands

### Installation and Setup
```bash
# Install the auto-updater system
sudo ./install.sh

# Uninstall the entire system
sudo ./install.sh uninstall
```

### Manual Discord Updates
```bash
# Update Discord now
sudo discord-auto-updater.sh

# Force update even if versions match
sudo discord-auto-updater.sh --force

# Check for updates without installing
sudo discord-auto-updater.sh --check-only

# Show current installed version
sudo discord-auto-updater.sh --version

# Run in silent mode
sudo discord-auto-updater.sh --silent
```

### Service Management
```bash
# Check timer status
sudo systemctl status discord-auto-updater.timer

# View service logs
sudo journalctl -u discord-auto-updater.service

# Control automatic updates
sudo systemctl stop discord-auto-updater.timer
sudo systemctl start discord-auto-updater.timer
sudo systemctl disable discord-auto-updater.timer
```

### Testing and Debugging
```bash
# Test script execution
sudo discord-auto-updater.sh --help

# Follow live logs
sudo tail -f /var/log/discord-updater.log

# Check systemd timer schedule
sudo systemctl list-timers discord-auto-updater.timer

# Validate systemd files
sudo systemd-analyze verify /etc/systemd/system/discord-auto-updater.timer
```

## Key Features

- **Version Detection**: Compares installed Discord version with latest available using dpkg
- **Safe Downloads**: Downloads from official Discord URLs with integrity verification
- **Backup System**: Creates backup information before updates
- **Lock File Management**: Prevents multiple simultaneous executions
- **Comprehensive Logging**: Logs to both /var/log/discord-updater.log and systemd journal
- **Systemd Integration**: Daily automated checks with randomized delays
- **Security Hardening**: Systemd service runs with restricted permissions (PrivateTmp, ProtectSystem, etc.)

## File Locations

- Script: `/usr/local/bin/discord-auto-updater.sh`
- Configuration: `/etc/discord-updater.conf`
- Logs: `/var/log/discord-updater.log`
- Systemd files: `/etc/systemd/system/discord-auto-updater.{service,timer}`
- Lock file: `/var/run/discord-updater.lock`
- Temp directory: `/tmp/discord-updater`

## Configuration Options

Edit `/etc/discord-updater.conf` to customize:
- `DEFAULT_UPDATE_CHECK`: Enable/disable automatic checks
- `DEFAULT_FORCE_UPDATE`: Force updates even if versions match
- `DEFAULT_SILENT`: Control console output verbosity
- `DEFAULT_BACKUP`: Enable/disable backup creation
- `DISCORD_URL`: Custom Discord download URL (advanced)
- `TEMP_DIR`: Custom temporary directory
- `LOG_FILE`: Custom log file location

## Security Considerations

This tool implements several security measures:
- Downloads only from official Discord URLs
- Package verification using dpkg integrity checks
- Systemd service hardening with restricted file system access
- Requires root privileges for system-wide installation
- Automatic cleanup of temporary files
- Lock file prevents concurrent executions

## Error Handling

The script includes comprehensive error handling for:
- Network connectivity issues
- Download failures
- Package verification failures
- Installation errors
- Dependency resolution
- Lock file management