#!/bin/bash

# Let's Encrypt Setup Script
# This script sets up the initial Let's Encrypt certificate and starts monitoring

set -e

# Configuration
COMPOSE_FILE="docker-compose.yml"
COMPOSE_LE_FILE="docker-compose.letsencrypt.yml"

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "ERROR: .env file not found. Please create it with the required variables:"
    echo "  DOMAIN=your-domain.com"
    echo "  KEYCLOAK_HOSTNAME=auth.your-domain.com"
    echo "  LETSENCRYPT_EMAIL=your-email@example.com"
    exit 1
fi

# Source environment variables
source .env

# Validate required environment variables
if [ -z "$DOMAIN" ] || [ -z "$KEYCLOAK_HOSTNAME" ] || [ -z "$LETSENCRYPT_EMAIL" ]; then
    echo "ERROR: Required environment variables not set in .env:"
    echo "  DOMAIN, KEYCLOAK_HOSTNAME, LETSENCRYPT_EMAIL"
    exit 1
fi

# Set trigger directory (with fallback default)
TRIGGER_DIR="${LETSENCRYPT_TRIGGER_DIR:-/var/lib/certbot}"

echo "Setting up Let's Encrypt for domains: $DOMAIN, $KEYCLOAK_HOSTNAME"
echo "Email: $LETSENCRYPT_EMAIL"

# Create trigger directory
mkdir -p "$TRIGGER_DIR"

# Make scripts executable
chmod +x scripts/*.sh

echo "Starting the stack with Let's Encrypt support..."

# Start the complete stack with Let's Encrypt integration
# This includes nginx with ACME challenge support and certbot
docker compose -f "$COMPOSE_FILE" -f "$COMPOSE_LE_FILE" up -d

# Wait for services to be ready
echo "Waiting for services to start..."
sleep 30

echo "Let's Encrypt setup initiated!"
echo ""
echo "Next steps:"
echo "1. Monitor the certbot logs: docker compose -f $COMPOSE_FILE -f $COMPOSE_LE_FILE logs -f certbot"
echo "2. Set up certificate monitoring: ./scripts/setup-letsencrypt-cron.sh"
echo "3. Test manual monitoring: ./scripts/letsencrypt-monitor.sh"
echo ""
echo "The system will automatically:"
echo "- Generate initial certificates"
echo "- Set up automatic renewal (twice daily)"
echo "- Reload services when certificates are renewed"