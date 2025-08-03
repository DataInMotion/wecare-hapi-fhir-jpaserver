#!/bin/bash

set -e

echo "Starting initial certificate generation for domains: ${DOMAIN}, ${KEYCLOAK_DOMAIN}"

# Wait a bit more to ensure nginx is fully ready
sleep 10

# Generate initial certificates
certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email ${LETSENCRYPT_EMAIL} \
    --agree-tos \
    --no-eff-email \
    --expand \
    --domains ${DOMAIN},${KEYCLOAK_DOMAIN} \
    --non-interactive

if [ $? -eq 0 ]; then
    echo "Initial certificates generated successfully!"
    
    # Copy certificates to nginx-accessible location
    /opt/certbot-hooks/copy-certs.sh
    
    # Signal host to reload services
    echo "Creating reload triggers for initial setup..."
    touch /var/lib/certbot/reload-nginx
    touch /var/lib/certbot/restart-keycloak
    
    echo "Certificate installation completed! Host should reload services."
else
    echo "Certificate generation failed!"
    exit 1
fi