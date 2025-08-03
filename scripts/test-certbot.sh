#!/bin/bash

# Test script for certbot setup
# This helps diagnose issues with the Let's Encrypt integration

set -e

COMPOSE_FILE="docker-compose.yml"
COMPOSE_LE_FILE="docker-compose.letsencrypt.yml"

# Load environment variables if .env exists
if [ -f ".env" ]; then
    source .env
fi

# Set trigger directory (with fallback default)
TRIGGER_DIR="${LETSENCRYPT_TRIGGER_DIR:-/var/lib/certbot}"

echo "=== Let's Encrypt Certbot Test ==="
echo ""

# Check if services are running
echo "1. Checking service status..."
if docker compose -f "$COMPOSE_FILE" -f "$COMPOSE_LE_FILE" ps | grep -q "certbot"; then
    echo "✅ Certbot service is running"
else
    echo "❌ Certbot service is not running"
    echo "   Run: docker compose -f $COMPOSE_FILE -f $COMPOSE_LE_FILE up -d"
    exit 1
fi

# Test nginx ACME challenge endpoint
echo ""
echo "2. Testing nginx ACME challenge endpoint..."
if curl -f http://localhost/.well-known/acme-challenge/health-check >/dev/null 2>&1; then
    echo "✅ Nginx ACME challenge endpoint is accessible"
else
    echo "❌ Nginx ACME challenge endpoint is not accessible"
    echo "   Check nginx configuration and ensure port 80 is accessible"
fi

# Check certbot logs for errors
echo ""
echo "3. Checking certbot logs for recent errors..."
if docker compose -f "$COMPOSE_FILE" -f "$COMPOSE_LE_FILE" logs --tail=20 certbot | grep -i error; then
    echo "❌ Found errors in certbot logs (see above)"
else
    echo "✅ No recent errors found in certbot logs"
fi

# Check certificate status
echo ""
echo "4. Checking certificate status..."
docker compose -f "$COMPOSE_FILE" -f "$COMPOSE_LE_FILE" exec certbot certbot certificates || echo "No certificates found yet"

# Check trigger directory
echo ""
echo "5. Checking trigger directory..."
if [ -d "$TRIGGER_DIR" ]; then
    echo "✅ Trigger directory exists: $TRIGGER_DIR"
    ls -la "$TRIGGER_DIR/" || echo "Directory is empty"
else
    echo "❌ Trigger directory does not exist: $TRIGGER_DIR"
fi

echo ""
echo "=== Test Complete ==="
echo ""
echo "If you see errors above, check:"
echo "1. DNS points to this server"
echo "2. Firewall allows HTTP (port 80) and HTTPS (port 443)"
echo "3. Environment variables are set correctly in .env"
echo "4. Services are running: docker compose -f $COMPOSE_FILE -f $COMPOSE_LE_FILE ps"