#!/bin/bash

# Install Let's Encrypt monitor as systemd service

set -e

# Get the current directory (project root)
PROJECT_DIR=$(pwd)
SERVICE_NAME="letsencrypt-monitor"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root or with sudo"
    exit 1
fi

echo "Installing Let's Encrypt monitor as systemd service..."
echo "Project directory: $PROJECT_DIR"

# Create systemd service file
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Let's Encrypt Certificate Monitor for HAPI FHIR
After=docker.service
Requires=docker.service

[Service]
Type=simple
User=root
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/scripts/letsencrypt-monitor.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
systemctl daemon-reload

# Enable and start the service
systemctl enable "$SERVICE_NAME"
systemctl start "$SERVICE_NAME"

echo "Systemd service installed and started!"
echo ""
echo "Useful commands:"
echo "  Check status: systemctl status $SERVICE_NAME"
echo "  View logs: journalctl -u $SERVICE_NAME -f"
echo "  Stop service: systemctl stop $SERVICE_NAME"
echo "  Disable service: systemctl disable $SERVICE_NAME"
echo ""
echo "The service will automatically start on system boot."