#!/bin/bash

# Discord Auto-Updater Installation Script
# This script installs the Discord auto-updater system on Debian/Ubuntu

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Installation paths
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc"
SYSTEMD_DIR="/etc/systemd/system"
LOG_DIR="/var/log"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Print colored output
print_status() {
    local color="$1"
    local message="$2"
    echo -e "${color}[INFO]${NC} $message"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check system requirements
check_requirements() {
    print_status "$BLUE" "Checking system requirements..."
    
    # Check if we're on a Debian-based system
    if ! command -v dpkg >/dev/null 2>&1; then
        print_error "This system doesn't appear to be Debian/Ubuntu based (dpkg not found)"
        exit 1
    fi
    
    # Check for required tools
    local missing_tools=()
    
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        missing_tools+=("curl or wget")
    fi
    
    if ! command -v systemctl >/dev/null 2>&1; then
        missing_tools+=("systemd")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_status "$YELLOW" "Installing missing packages..."
        
        apt-get update
        
        if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
            apt-get install -y curl
        fi
    fi
    
    print_success "System requirements satisfied"
}

# Install the main script
install_script() {
    print_status "$BLUE" "Installing Discord auto-updater script..."
    
    local source_script="$SCRIPT_DIR/discord-auto-updater.sh"
    local target_script="$INSTALL_DIR/discord-auto-updater.sh"
    
    if [[ ! -f "$source_script" ]]; then
        print_error "Source script not found: $source_script"
        exit 1
    fi
    
    cp "$source_script" "$target_script"
    chmod +x "$target_script"
    
    print_success "Script installed to $target_script"
}

# Install configuration file
install_config() {
    print_status "$BLUE" "Installing configuration file..."
    
    local source_config="$SCRIPT_DIR/discord-updater.conf"
    local target_config="$CONFIG_DIR/discord-updater.conf"
    
    if [[ -f "$target_config" ]]; then
        print_warning "Configuration file already exists at $target_config"
        print_status "$YELLOW" "Creating backup and installing new config..."
        cp "$target_config" "$target_config.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    if [[ -f "$source_config" ]]; then
        cp "$source_config" "$target_config"
        print_success "Configuration file installed to $target_config"
    else
        print_warning "Default configuration file not found, creating minimal config..."
        cat > "$target_config" <<EOF
# Discord Auto-Updater Configuration
DEFAULT_UPDATE_CHECK=1
DEFAULT_FORCE_UPDATE=0
DEFAULT_SILENT=0
DEFAULT_BACKUP=1
EOF
        print_success "Minimal configuration file created"
    fi
}

# Install systemd service and timer
install_systemd() {
    print_status "$BLUE" "Installing systemd service and timer..."
    
    local source_service="$SCRIPT_DIR/discord-auto-updater.service"
    local source_timer="$SCRIPT_DIR/discord-auto-updater.timer"
    local target_service="$SYSTEMD_DIR/discord-auto-updater.service"
    local target_timer="$SYSTEMD_DIR/discord-auto-updater.timer"
    
    # Update service file to use correct script path
    if [[ -f "$source_service" ]]; then
        sed "s|/usr/local/bin/discord-auto-updater.sh|$INSTALL_DIR/discord-auto-updater.sh|g" "$source_service" > "$target_service"
    else
        # Create service file if it doesn't exist
        cat > "$target_service" <<EOF
[Unit]
Description=Discord Auto-Updater
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=root
ExecStart=$INSTALL_DIR/discord-auto-updater.sh --silent
StandardOutput=journal
StandardError=journal
PrivateTmp=yes
ProtectSystem=strict
ReadWritePaths=/var/log /var/run /tmp
ProtectHome=yes
NoNewPrivileges=yes

[Install]
WantedBy=multi-user.target
EOF
    fi
    
    # Install timer file
    if [[ -f "$source_timer" ]]; then
        cp "$source_timer" "$target_timer"
    else
        # Create timer file if it doesn't exist
        cat > "$target_timer" <<EOF
[Unit]
Description=Discord Auto-Updater Timer
Requires=discord-auto-updater.service

[Timer]
OnCalendar=daily
Persistent=true
RandomizedDelaySec=2h

[Install]
WantedBy=timers.target
EOF
    fi
    
    # Reload systemd daemon
    systemctl daemon-reload
    
    print_success "Systemd service and timer installed"
}

# Enable and start the systemd timer
enable_service() {
    print_status "$BLUE" "Enabling and starting Discord auto-updater timer..."
    
    # Enable and start the timer
    systemctl enable discord-auto-updater.timer
    systemctl start discord-auto-updater.timer
    
    print_success "Discord auto-updater timer enabled and started"
    
    # Show timer status
    print_status "$BLUE" "Timer status:"
    if systemctl is-active discord-auto-updater.timer >/dev/null 2>&1; then
        print_success "Timer is active and running"
        
        # Get next run time in a readable format
        local next_run=$(systemctl list-timers discord-auto-updater.timer --no-pager | grep discord-auto-updater.timer | awk '{print $1, $2, $3}' 2>/dev/null || echo "Unknown")
        if [[ "$next_run" != "Unknown" && "$next_run" != "" ]]; then
            print_status "$BLUE" "Next automatic check: $next_run"
        else
            print_status "$BLUE" "Next check scheduled within 24 hours"
        fi
    else
        print_error "Timer is not active"
    fi
}

# Create log directory
setup_logging() {
    print_status "$BLUE" "Setting up logging..."
    
    local log_file="$LOG_DIR/discord-updater.log"
    
    # Create log file if it doesn't exist
    touch "$log_file"
    chmod 644 "$log_file"
    
    print_success "Logging configured: $log_file"
}

# Test the installation
test_installation() {
    print_status "$BLUE" "Testing installation..."
    
    local script_path="$INSTALL_DIR/discord-auto-updater.sh"
    
    # Test script execution
    if "$script_path" --help >/dev/null 2>&1; then
        print_success "Script execution test passed"
    else
        print_error "Script execution test failed"
        return 1
    fi
    
    # Test configuration loading
    if "$script_path" --version >/dev/null 2>&1; then
        print_success "Configuration test passed"
    else
        print_warning "Configuration test had issues, but installation should still work"
    fi
    
    print_success "Installation test completed"
}

# Show post-installation information
show_usage_info() {
    cat << EOF

=== Discord Auto-Updater Successfully Installed ===

The Discord auto-updater has been installed and configured to run daily.

Manual Commands:
  Update Discord now:           sudo discord-auto-updater.sh
  Force update:                 sudo discord-auto-updater.sh --force
  Check for updates only:       sudo discord-auto-updater.sh --check-only
  Show current version:         sudo discord-auto-updater.sh --version
  View help:                    sudo discord-auto-updater.sh --help

Service Management:
  Check timer status:           sudo systemctl status discord-auto-updater.timer
  View logs:                    sudo journalctl -u discord-auto-updater.service
  Stop auto-updates:            sudo systemctl stop discord-auto-updater.timer
  Start auto-updates:           sudo systemctl start discord-auto-updater.timer
  Disable auto-updates:         sudo systemctl disable discord-auto-updater.timer

Configuration:
  Edit config:                  sudo nano /etc/discord-updater.conf
  View logs:                    sudo tail -f /var/log/discord-updater.log

Next Steps:
1. The timer will automatically check for Discord updates daily
2. You can customize the behavior by editing /etc/discord-updater.conf
3. Check the logs at /var/log/discord-updater.log for update history

Note: The first update check will happen within the next 24 hours, or you can run it manually now.

EOF
}

# Uninstallation function
uninstall() {
    print_status "$BLUE" "Uninstalling Discord Auto-Updater..."
    
    # Stop and disable service
    systemctl stop discord-auto-updater.timer 2>/dev/null || true
    systemctl disable discord-auto-updater.timer 2>/dev/null || true
    
    # Remove systemd files
    rm -f "$SYSTEMD_DIR/discord-auto-updater.service"
    rm -f "$SYSTEMD_DIR/discord-auto-updater.timer"
    
    # Remove script
    rm -f "$INSTALL_DIR/discord-auto-updater.sh"
    
    # Ask about configuration and logs
    read -p "Remove configuration file? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f "$CONFIG_DIR/discord-updater.conf"
        print_status "$GREEN" "Configuration file removed"
    fi
    
    read -p "Remove log file? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f "$LOG_DIR/discord-updater.log"
        print_status "$GREEN" "Log file removed"
    fi
    
    # Reload systemd
    systemctl daemon-reload
    
    print_success "Discord Auto-Updater uninstalled successfully"
}

# Main installation function
main() {
    case "${1:-install}" in
        "install")
            print_status "$GREEN" "Starting Discord Auto-Updater installation..."
            check_root
            check_requirements
            install_script
            install_config
            install_systemd
            setup_logging
            enable_service
            test_installation
            show_usage_info
            ;;
        "uninstall")
            print_status "$YELLOW" "Starting Discord Auto-Updater uninstallation..."
            check_root
            uninstall
            ;;
        "--help"|"-h")
            cat << EOF
Discord Auto-Updater Installation Script

Usage: $0 [COMMAND]

COMMANDS:
    install     Install Discord Auto-Updater (default)
    uninstall   Remove Discord Auto-Updater
    --help      Show this help message

EXAMPLES:
    sudo $0                    # Install the auto-updater
    sudo $0 install           # Install the auto-updater  
    sudo $0 uninstall         # Remove the auto-updater

EOF
            ;;
        *)
            print_error "Unknown command: $1"
            print_status "$BLUE" "Use '$0 --help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"