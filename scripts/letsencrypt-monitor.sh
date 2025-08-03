#!/bin/bash

# Let's Encrypt Certificate Monitor
# This script monitors for certificate renewal triggers and reloads services
# Run this as a systemd service or in a screen/tmux session

set -e

COMPOSE_FILE="docker-compose.yml"
COMPOSE_LE_FILE="docker-compose.letsencrypt.yml"

# Load environment variables if .env exists
if [ -f ".env" ]; then
    source .env
fi

# Set trigger directory (with fallback default)
TRIGGER_DIR="${LETSENCRYPT_TRIGGER_DIR:-/var/lib/certbot}"

echo "Starting Let's Encrypt certificate monitor..."
echo "Monitoring directory: $TRIGGER_DIR"

# Create trigger directory if it doesn't exist
mkdir -p "$TRIGGER_DIR"

# Function to log with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1"
}

# Function to reload nginx
reload_nginx() {
    log "Reloading nginx configuration..."
    if docker compose -f "$COMPOSE_FILE" -f "$COMPOSE_LE_FILE" exec nginx nginx -s reload; then
        log "Nginx reloaded successfully"
        return 0
    else
        log "ERROR: Failed to reload nginx"
        return 1
    fi
}

# Function to restart keycloak
restart_keycloak() {
    log "Restarting keycloak to reload certificates..."
    if docker compose -f "$COMPOSE_FILE" -f "$COMPOSE_LE_FILE" restart auth.mi-jn.de; then
        log "Keycloak restarted successfully"
        return 0
    else
        log "ERROR: Failed to restart keycloak"
        return 1
    fi
}

# Main monitoring loop
while true; do
    # Check for nginx reload trigger
    if [ -f "$TRIGGER_DIR/reload-nginx" ]; then
        log "Found nginx reload trigger"
        if reload_nginx; then
            rm -f "$TRIGGER_DIR/reload-nginx"
            log "Nginx reload trigger processed"
        else
            log "Nginx reload failed, keeping trigger file"
        fi
    fi
    
    # Check for keycloak restart trigger
    if [ -f "$TRIGGER_DIR/restart-keycloak" ]; then
        log "Found keycloak restart trigger"
        if restart_keycloak; then
            rm -f "$TRIGGER_DIR/restart-keycloak"
            log "Keycloak restart trigger processed"
        else
            log "Keycloak restart failed, keeping trigger file"
        fi
    fi
    
    # Sleep for 30 seconds before checking again
    sleep 30
done