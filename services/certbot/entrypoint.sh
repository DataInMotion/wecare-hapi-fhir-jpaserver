#!/bin/bash

# Exit on any error
set -e

# Handle signals properly
trap 'echo "Received shutdown signal"; exit 0' SIGTERM SIGINT

# Wait for nginx to be ready
echo "Waiting for nginx to be ready..."
until curl -f http://nginx:80/.well-known/acme-challenge/health-check 2>/dev/null || [ $? -eq 22 ]; do
    echo "Waiting for nginx..."
    sleep 5
done

# Check if certificates already exist
if [ ! -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]; then
    echo "No existing certificates found. Running initial certificate generation..."
    /opt/certbot-hooks/initial-cert.sh
else
    echo "Existing certificates found."
fi

# Start cron daemon with proper signal handling
echo "Starting certificate renewal cron..."
if [ "$1" = "crond" ]; then
    # Start crond in foreground mode
    exec crond -f -l 2
else
    exec "$@"
fi