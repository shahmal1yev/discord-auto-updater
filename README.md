# Discord Auto-Updater for Debian/Ubuntu

Automatic Discord updater for Debian/Ubuntu systems. Since Discord doesn't provide an official APT repository, this tool automatically updates Discord to keep you on the latest version without manual intervention.

## ✨ Features

- 🔄 Automatic version checking and updates
- ⏰ Daily checks via systemd timer
- 🛡️ Safe download and package verification
- 📝 Comprehensive logging system
- ⚙️ Configuration file support
- 🔐 System-wide installation with proper permissions
- 🚨 Desktop notifications for updates
- 💾 Backup creation before updates
- 🔒 Lock file prevents multiple instances
- 🧹 Automatic cleanup of temporary files

## 📋 System Requirements

- Debian/Ubuntu or other dpkg-based systems
- Root privileges (sudo)
- Internet connection
- `curl` or `wget` (automatically installed if missing)
- `systemd` (for scheduled updates)

## 🚀 Installation

### Quick Installation

```bash
# Clone the repository
git clone <repository-url>
cd discord-auto-updater

# Run the installation script
sudo ./install.sh
```

### Manual Installation

```bash
# Copy script to system location
sudo cp discord-auto-updater.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/discord-auto-updater.sh

# Create configuration file
sudo cp discord-updater.conf /etc/

# Install systemd files
sudo cp discord-auto-updater.service /etc/systemd/system/
sudo cp discord-auto-updater.timer /etc/systemd/system/

# Reload and enable systemd
sudo systemctl daemon-reload
sudo systemctl enable discord-auto-updater.timer
sudo systemctl start discord-auto-updater.timer
```

## 🎮 Usage

### Basic Commands

```bash
# Update Discord now
sudo discord-auto-updater.sh

# Force update (even if versions match)
sudo discord-auto-updater.sh --force

# Check only, don't install
sudo discord-auto-updater.sh --check-only

# Show current version
sudo discord-auto-updater.sh --version

# Help information
sudo discord-auto-updater.sh --help

# Silent mode (no console output)
sudo discord-auto-updater.sh --silent
```

### Service Management

```bash
# Check timer status
sudo systemctl status discord-auto-updater.timer

# View logs
sudo journalctl -u discord-auto-updater.service

# Stop automatic updates
sudo systemctl stop discord-auto-updater.timer

# Start automatic updates
sudo systemctl start discord-auto-updater.timer

# Disable automatic updates completely
sudo systemctl disable discord-auto-updater.timer

# See next scheduled run
sudo systemctl list-timers discord-auto-updater.timer
```

## ⚙️ Configuration

Configuration file: `/etc/discord-updater.conf`

```bash
# Enable automatic update checks (1 = enabled, 0 = disabled)
DEFAULT_UPDATE_CHECK=1

# Force updates even if versions match (1 = enabled, 0 = disabled)
DEFAULT_FORCE_UPDATE=0

# Silent mode - suppress console output (1 = silent, 0 = verbose)
DEFAULT_SILENT=0

# Create backup before updates (1 = enabled, 0 = disabled)
DEFAULT_BACKUP=1
```

### Advanced Configuration

```bash
# Custom Discord download URL (advanced users only)
DISCORD_URL="https://discord.com/api/download?platform=linux&format=deb"

# Custom temporary directory
TEMP_DIR="/tmp/discord-updater"

# Custom log file location
LOG_FILE="/var/log/discord-updater.log"
```

## 📊 Logging System

Log file: `/var/log/discord-updater.log`

```bash
# Follow live logs
sudo tail -f /var/log/discord-updater.log

# Last 50 lines
sudo tail -n 50 /var/log/discord-updater.log

# Systemd logs
sudo journalctl -u discord-auto-updater.service -f

# View logs with timestamps
sudo journalctl -u discord-auto-updater.service --since "1 hour ago"
```

## 🔧 Troubleshooting

### Common Issues

**Problem:** Discord not updating
```bash
# Check manually
sudo discord-auto-updater.sh --check-only

# Check logs
sudo tail -n 20 /var/log/discord-updater.log

# Test internet connection
curl -I https://discord.com
```

**Problem:** Permission denied
```bash
# Check script permissions
ls -la /usr/local/bin/discord-auto-updater.sh

# Fix permissions
sudo chmod +x /usr/local/bin/discord-auto-updater.sh
```

**Problem:** Systemd timer not working
```bash
# Check timer status
sudo systemctl status discord-auto-updater.timer

# Restart timer
sudo systemctl restart discord-auto-updater.timer

# Check if timer is enabled
sudo systemctl is-enabled discord-auto-updater.timer
```

**Problem:** Download failures
```bash
# Test direct download
curl -I "https://discord.com/api/download?platform=linux&format=deb"

# Check DNS resolution
nslookup discord.com

# Verify proxy settings if applicable
echo $http_proxy $https_proxy
```

### Testing and Debugging

```bash
# Test configuration loading
sudo discord-auto-updater.sh --check-only

# Run with verbose logging
sudo discord-auto-updater.sh

# Manual service execution
sudo systemctl start discord-auto-updater.service

# Check service status
sudo systemctl status discord-auto-updater.service

# Validate systemd timer syntax
sudo systemd-analyze verify /etc/systemd/system/discord-auto-updater.timer
```

## 🗑️ Uninstallation

### Automatic Uninstallation

```bash
sudo ./install.sh uninstall
```

### Manual Uninstallation

```bash
# Stop and disable service
sudo systemctl stop discord-auto-updater.timer
sudo systemctl disable discord-auto-updater.timer

# Remove files
sudo rm -f /usr/local/bin/discord-auto-updater.sh
sudo rm -f /etc/systemd/system/discord-auto-updater.service
sudo rm -f /etc/systemd/system/discord-auto-updater.timer
sudo rm -f /etc/discord-updater.conf

# Optionally remove log file
sudo rm -f /var/log/discord-updater.log

# Reload systemd
sudo systemctl daemon-reload
```

## 📁 File Structure

```
discord-auto-updater/
├── discord-auto-updater.sh     # Main updater script
├── discord-auto-updater.service # Systemd service file
├── discord-auto-updater.timer   # Systemd timer file
├── discord-updater.conf         # Configuration template
├── install.sh                   # Installation script
└── README.md                    # This document
```

## 🔒 Security Features

- Downloads only from official Discord URLs
- Package verification and integrity checks
- Requires root privileges for system-wide installation
- Temporary files are automatically cleaned up
- Systemd security restrictions applied (PrivateTmp, ProtectSystem, etc.)
- Lock file prevents multiple simultaneous executions
- Safe error handling and rollback capabilities

## 📈 How It Works

1. **Version Detection**: Compares installed Discord version with latest available
2. **Secure Download**: Downloads official Discord .deb package from Discord's servers  
3. **Verification**: Validates downloaded package integrity and authenticity
4. **Backup**: Creates backup information before updates (optional)
5. **Installation**: Uses dpkg/apt to safely install the new version
6. **Cleanup**: Removes temporary files and sends notifications
7. **Logging**: Records all operations for audit and troubleshooting

## 🤝 Contributing

1. Fork this repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow bash best practices and use `shellcheck`
- Test on multiple Debian/Ubuntu versions
- Maintain backward compatibility
- Update documentation for new features
- Add appropriate error handling and logging

## 📜 License

This project is licensed under the MIT License. See the LICENSE file for details.

## 💡 Feature Requests and Bug Reports

If you encounter issues or have suggestions, please report them in the GitHub Issues section.

## ❓ FAQ

**Q:** When does the update check happen?  
**A:** Daily with a randomized delay of up to 2 hours to distribute server load.

**Q:** Can updates happen while Discord is running?  
**A:** Yes, but Discord will need to be restarted to use the new version.

**Q:** Are there update notifications?  
**A:** Yes, via desktop notifications (if available) and log entries.

**Q:** How are versions compared?  
**A:** Using dpkg's built-in package version comparison system.

**Q:** What happens if Discord is already up to date?  
**A:** The script exits gracefully without making changes.

**Q:** Can I customize the update schedule?  
**A:** Yes, edit the systemd timer file or disable it and use cron instead.

**Q:** Is this safe to use on production systems?  
**A:** Yes, the script includes safety checks, backups, and proper error handling.

## 🚀 Quick Start Example

```bash
# Download and install
git clone <repository-url>
cd discord-auto-updater
sudo ./install.sh

# Verify installation
sudo discord-auto-updater.sh --version
sudo systemctl status discord-auto-updater.timer

# Manual update (optional)
sudo discord-auto-updater.sh

# Check logs
sudo tail -f /var/log/discord-updater.log
```

---

**Note:** This tool is not an official Discord product and is not supported by Discord's official support team. Use at your own discretion.
