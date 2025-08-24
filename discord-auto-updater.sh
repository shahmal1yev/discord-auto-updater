#!/bin/bash

# Discord Auto-Updater for Debian/Ubuntu
# Automatically checks and updates Discord to the latest version
# Author: System Administrator
# Version: 1.0

set -euo pipefail

# Configuration
DISCORD_URL="https://discord.com/api/download?platform=linux&format=deb"
TEMP_DIR="/tmp/discord-updater"
LOG_FILE="/var/log/discord-updater.log"
CONFIG_FILE="/etc/discord-updater.conf"
LOCK_FILE="/var/run/discord-updater.lock"

# Default configuration
DEFAULT_UPDATE_CHECK=1
DEFAULT_FORCE_UPDATE=0
DEFAULT_SILENT=0
DEFAULT_BACKUP=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    if [[ "$DEFAULT_SILENT" -eq 0 ]]; then
        case "$level" in
            "ERROR")   echo -e "${RED}[$level]${NC} $message" >&2 ;;
            "SUCCESS") echo -e "${GREEN}[$level]${NC} $message" ;;
            "WARNING") echo -e "${YELLOW}[$level]${NC} $message" ;;
            "INFO")    echo -e "${BLUE}[$level]${NC} $message" ;;
            *)         echo "[$level] $message" ;;
        esac
    fi
}

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        log "INFO" "Configuration loaded from $CONFIG_FILE"
    else
        log "INFO" "Using default configuration"
    fi
}

# Create lock file to prevent multiple instances
acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            log "ERROR" "Another instance is already running (PID: $pid)"
            exit 1
        else
            log "WARNING" "Removing stale lock file"
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
    trap 'rm -f "$LOCK_FILE"; exit' INT TERM EXIT
}

# Get installed Discord version
get_installed_version() {
    # Use more specific dpkg query for better reliability
    local version=$(dpkg-query -W -f='${Version}' discord 2>/dev/null || echo "")
    if [[ -n "$version" ]]; then
        echo "$version"
    else
        echo "not_installed"
    fi
}

# Get latest Discord version from downloaded package
get_package_version() {
    local deb_file="$1"
    dpkg-deb -f "$deb_file" Version 2>/dev/null || echo "unknown"
}

# Download Discord package
download_discord() {
    local download_path="$1"
    
    log "INFO" "Downloading Discord from $DISCORD_URL"
    
    if command -v curl >/dev/null 2>&1; then
        curl -L -o "$download_path" "$DISCORD_URL" --progress-bar
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$download_path" "$DISCORD_URL" --progress=bar:force
    else
        log "ERROR" "Neither curl nor wget found. Please install one of them."
        return 1
    fi
    
    if [[ ! -f "$download_path" ]]; then
        log "ERROR" "Failed to download Discord package"
        return 1
    fi
    
    log "SUCCESS" "Discord package downloaded successfully"
    return 0
}

# Verify downloaded package
verify_package() {
    local deb_file="$1"
    
    log "INFO" "Verifying downloaded package"
    
    # Check if it's a valid deb package
    if ! dpkg-deb -I "$deb_file" >/dev/null 2>&1; then
        log "ERROR" "Downloaded file is not a valid .deb package"
        return 1
    fi
    
    # Check package name
    local package_name=$(dpkg-deb -f "$deb_file" Package 2>/dev/null)
    if [[ "$package_name" != "discord" ]]; then
        log "ERROR" "Package name mismatch. Expected 'discord', got '$package_name'"
        return 1
    fi
    
    log "SUCCESS" "Package verification completed"
    return 0
}

# Backup current Discord installation
backup_discord() {
    if [[ "$DEFAULT_BACKUP" -eq 1 ]] && dpkg -l | grep -q "discord"; then
        local backup_dir="/var/backups/discord"
        local timestamp=$(date '+%Y%m%d_%H%M%S')
        
        log "INFO" "Creating backup of current Discord installation"
        
        mkdir -p "$backup_dir"
        
        # Create a simple backup info file
        cat > "$backup_dir/discord_backup_$timestamp.info" <<EOF
Backup Date: $(date)
Installed Version: $(get_installed_version)
Backup Method: Pre-update backup
EOF
        
        log "SUCCESS" "Backup information saved to $backup_dir/discord_backup_$timestamp.info"
    fi
}

# Install Discord package
install_discord() {
    local deb_file="$1"
    
    log "INFO" "Installing Discord package"
    
    # Use dpkg to install, then apt to fix dependencies if needed
    if dpkg -i "$deb_file" 2>/dev/null; then
        log "SUCCESS" "Discord installed successfully"
    else
        log "WARNING" "dpkg installation had issues, fixing dependencies"
        if apt-get install -f -y; then
            log "SUCCESS" "Dependencies fixed, Discord installed successfully"
        else
            log "ERROR" "Failed to install Discord and fix dependencies"
            return 1
        fi
    fi
    
    return 0
}

# Main update function
update_discord() {
    log "INFO" "Starting Discord update check"
    
    local installed_version=$(get_installed_version)
    log "INFO" "Current installed version: $installed_version"
    
    # Create temporary directory
    mkdir -p "$TEMP_DIR"
    local temp_deb="$TEMP_DIR/discord.deb"
    
    # Download latest Discord
    if ! download_discord "$temp_deb"; then
        log "ERROR" "Failed to download Discord"
        return 1
    fi
    
    # Verify package
    if ! verify_package "$temp_deb"; then
        log "ERROR" "Package verification failed"
        rm -f "$temp_deb"
        return 1
    fi
    
    # Get version from downloaded package
    local latest_version=$(get_package_version "$temp_deb")
    log "INFO" "Latest available version: $latest_version"
    
    # Check if update is needed
    if [[ "$installed_version" != "not_installed" ]] && [[ "$installed_version" == "$latest_version" ]] && [[ "$DEFAULT_FORCE_UPDATE" -eq 0 ]]; then
        log "INFO" "Discord is already up to date"
        rm -f "$temp_deb"
        return 0
    fi
    
    # Backup current installation
    backup_discord
    
    # Install Discord
    if install_discord "$temp_deb"; then
        # Wait a moment for dpkg database to update
        sleep 1
        local new_version=$(get_installed_version)
        log "SUCCESS" "Discord updated successfully from $installed_version to $new_version"
        
        # Send notification if desktop environment is available
        if command -v notify-send >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
            notify-send "Discord Updated" "Discord has been updated to version $new_version" --icon=discord 2>/dev/null || true
        fi
    else
        log "ERROR" "Failed to install Discord"
        rm -f "$temp_deb"
        return 1
    fi
    
    # Cleanup
    rm -f "$temp_deb"
    return 0
}

# Show usage information
show_usage() {
    cat << EOF
Discord Auto-Updater for Debian/Ubuntu

Usage: $0 [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    -f, --force         Force update even if versions match
    -s, --silent        Silent mode (no console output)
    -c, --config FILE   Use custom configuration file
    -l, --log FILE      Use custom log file
    --check-only        Only check for updates, don't install
    --version           Show current installed version

EXAMPLES:
    $0                  # Check and update Discord if needed
    $0 --force          # Force update regardless of version
    $0 --check-only     # Only check for updates
    $0 --silent         # Update silently

CONFIGURATION:
    Edit $CONFIG_FILE to customize behavior:
    
    DEFAULT_UPDATE_CHECK=1    # Enable automatic update checks
    DEFAULT_FORCE_UPDATE=0    # Don't force updates by default
    DEFAULT_SILENT=0          # Show output by default
    DEFAULT_BACKUP=1          # Create backups by default

SYSTEMD SERVICE:
    To enable automatic updates, install as systemd service:
    sudo ./discord-auto-updater.sh --install-service

EOF
}

# Install systemd service
install_service() {
    local script_path=$(realpath "$0")
    
    log "INFO" "Installing systemd service"
    
    # Create systemd service file
    cat > /etc/systemd/system/discord-auto-updater.service <<EOF
[Unit]
Description=Discord Auto-Updater
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=root
ExecStart=$script_path --silent
StandardOutput=journal
StandardError=journal
EOF

    # Create systemd timer file
    cat > /etc/systemd/system/discord-auto-updater.timer <<EOF
[Unit]
Description=Discord Auto-Updater Timer
Requires=discord-auto-updater.service

[Timer]
OnCalendar=daily
Persistent=true
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
EOF

    # Reload systemd and enable timer
    systemctl daemon-reload
    systemctl enable discord-auto-updater.timer
    systemctl start discord-auto-updater.timer
    
    log "SUCCESS" "Systemd service installed and enabled"
    log "INFO" "Discord will be checked for updates daily"
    log "INFO" "Use 'systemctl status discord-auto-updater.timer' to check status"
}

# Main function
main() {
    local check_only=0
    local show_version=0
    local install_service_flag=0
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -f|--force)
                DEFAULT_FORCE_UPDATE=1
                shift
                ;;
            -s|--silent)
                DEFAULT_SILENT=1
                shift
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -l|--log)
                LOG_FILE="$2"
                shift 2
                ;;
            --check-only)
                check_only=1
                shift
                ;;
            --version)
                show_version=1
                shift
                ;;
            --install-service)
                install_service_flag=1
                shift
                ;;
            *)
                log "ERROR" "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Handle special cases
    if [[ "$show_version" -eq 1 ]]; then
        local version=$(get_installed_version)
        echo "Installed Discord version: $version"
        exit 0
    fi
    
    if [[ "$install_service_flag" -eq 1 ]]; then
        if [[ $EUID -ne 0 ]]; then
            log "ERROR" "Installing systemd service requires root privileges"
            exit 1
        fi
        install_service
        exit 0
    fi
    
    # Check if running as root (recommended for system-wide installation)
    if [[ $EUID -ne 0 ]] && [[ "$DEFAULT_SILENT" -eq 0 ]]; then
        log "WARNING" "Running without root privileges. Some features may not work properly."
    fi
    
    # Load configuration
    load_config
    
    # Acquire lock
    acquire_lock
    
    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Initialize log
    log "INFO" "Discord Auto-Updater starting (PID: $$)"
    
    if [[ "$check_only" -eq 1 ]]; then
        local installed_version=$(get_installed_version)
        echo "Current installed version: $installed_version"
        
        # Download to check latest version
        mkdir -p "$TEMP_DIR"
        local temp_deb="$TEMP_DIR/discord.deb"
        
        if download_discord "$temp_deb" && verify_package "$temp_deb"; then
            local latest_version=$(get_package_version "$temp_deb")
            echo "Latest available version: $latest_version"
            
            if [[ "$installed_version" != "not_installed" ]] && [[ "$installed_version" == "$latest_version" ]]; then
                echo "Discord is up to date"
            else
                echo "Update available"
            fi
        else
            echo "Failed to check latest version"
        fi
        
        rm -f "$temp_deb"
    else
        # Run update
        update_discord
    fi
    
    log "INFO" "Discord Auto-Updater completed"
}

# Run main function with all arguments
main "$@"