#!/bin/bash

set -e

echo "$(date): Starting certificate renewal check..."

# Attempt to renew certificates
certbot renew \
    --webroot \
    --webroot-path=/var/www/certbot \
    --quiet \
    --deploy-hook "/opt/certbot-hooks/deploy-hook.sh"

echo "$(date): Certificate renewal check completed."