#!/bin/bash

# Setup Let's Encrypt Certificate Monitor as Cronjob
# This script sets up a cronjob to check for certificate renewal triggers

set -e

# Get the current directory (project root)
PROJECT_DIR=$(pwd)
SCRIPT_PATH="$PROJECT_DIR/scripts/letsencrypt-monitor.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "ℹ️  $1"; }

echo "=== Let's Encrypt Certificate Monitor Cronjob Setup ==="
echo "Project directory: $PROJECT_DIR"
echo "Monitor script: $SCRIPT_PATH"
echo ""

# Check if script exists
if [ ! -f "$SCRIPT_PATH" ]; then
    print_error "Monitor script not found: $SCRIPT_PATH"
    exit 1
fi

# Make sure script is executable
chmod +x "$SCRIPT_PATH"

# Check current crontab
print_info "Checking current crontab..."
if crontab -l 2>/dev/null | grep -q "letsencrypt-monitor.sh"; then
    print_warning "Cronjob for letsencrypt-monitor.sh already exists"
    echo ""
    echo "Current cronjobs containing 'letsencrypt-monitor.sh':"
    crontab -l 2>/dev/null | grep "letsencrypt-monitor.sh"
    echo ""
    read -p "Do you want to replace the existing cronjob? (y/N): " REPLACE
    if [ "$REPLACE" != "y" ] && [ "$REPLACE" != "Y" ]; then
        echo "Cancelled."
        exit 0
    fi
    
    # Remove existing cronjob
    print_info "Removing existing cronjob..."
    (crontab -l 2>/dev/null | grep -v "letsencrypt-monitor.sh") | crontab -
fi

# Add new cronjob
print_info "Adding new cronjob..."

# Show cronjob options
echo ""
echo "Cronjob frequency options:"
echo "1. Every 5 minutes (recommended for testing)"
echo "2. Every 15 minutes (good for production)"
echo "3. Every hour"
echo "4. Every 6 hours"
echo "5. Custom schedule"

read -p "Choose option (1-5): " CRON_OPTION

case $CRON_OPTION in
    1)
        CRON_SCHEDULE="*/5 * * * *"
        DESCRIPTION="every 5 minutes"
        ;;
    2)
        CRON_SCHEDULE="*/15 * * * *"
        DESCRIPTION="every 15 minutes"
        ;;
    3)
        CRON_SCHEDULE="0 * * * *"
        DESCRIPTION="every hour"
        ;;
    4)
        CRON_SCHEDULE="0 */6 * * *"
        DESCRIPTION="every 6 hours"
        ;;
    5)
        read -p "Enter custom cron schedule (e.g., '0 */2 * * *'): " CRON_SCHEDULE
        DESCRIPTION="custom schedule: $CRON_SCHEDULE"
        ;;
    *)
        print_error "Invalid option"
        exit 1
        ;;
esac

# Create the cronjob entry
CRON_ENTRY="$CRON_SCHEDULE cd $PROJECT_DIR && $SCRIPT_PATH >> /var/log/letsencrypt-monitor.log 2>&1"

# Add to crontab
(crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -

print_success "Cronjob added successfully!"
echo ""
echo "Schedule: $DESCRIPTION"
echo "Command: $CRON_ENTRY"
echo ""

# Create log directory if it doesn't exist
print_info "Setting up logging..."
sudo touch /var/log/letsencrypt-monitor.log
sudo chmod 644 /var/log/letsencrypt-monitor.log

print_success "Logging configured: /var/log/letsencrypt-monitor.log"
echo ""

# Show management commands
echo "=== Management Commands ==="
echo ""
echo "# View current cronjobs:"
echo "crontab -l"
echo ""
echo "# View monitor logs:"
echo "tail -f /var/log/letsencrypt-monitor.log"
echo ""
echo "# Test manual run:"
echo "cd $PROJECT_DIR && $SCRIPT_PATH"
echo ""
echo "# Remove cronjob:"
echo "crontab -l | grep -v 'letsencrypt-monitor.sh' | crontab -"
echo ""

# Test run
print_info "Testing manual run..."
echo ""
cd "$PROJECT_DIR" && "$SCRIPT_PATH"
echo ""

print_success "Setup completed!"
echo ""
print_info "The cronjob will now check for certificate renewal triggers $DESCRIPTION"
print_warning "Monitor the logs to ensure it's working: tail -f /var/log/letsencrypt-monitor.log"