#!/bin/bash

set -e

echo "$(date): Certificate renewed, deploying new certificates..."

# Copy renewed certificates
/opt/certbot-hooks/copy-certs.sh

# Signal host to reload services by creating trigger files
echo "$(date): Creating reload triggers..."
touch /var/lib/certbot/reload-nginx
touch /var/lib/certbot/restart-keycloak

echo "$(date): Certificate deployment completed, triggers created for host!"