#!/bin/bash

set -e

CERT_DIR="/etc/letsencrypt/live/${DOMAIN}"
DEST_DIR="/etc/nginx/certs"

if [ -f "${CERT_DIR}/fullchain.pem" ] && [ -f "${CERT_DIR}/privkey.pem" ]; then
    echo "Copying certificates to nginx directory..."
    
    # Copy certificates for nginx
    cp "${CERT_DIR}/fullchain.pem" "${DEST_DIR}/cert.pem"
    cp "${CERT_DIR}/privkey.pem" "${DEST_DIR}/key.pem"
    
    # Copy certificates for keycloak (same files, different names)
    cp "${CERT_DIR}/fullchain.pem" "${DEST_DIR}/keycloak-cert.pem"
    cp "${CERT_DIR}/privkey.pem" "${DEST_DIR}/keycloak-key.pem"
    
    # Set proper permissions and ownership
    # Certificates can be world-readable
    chmod 644 "${DEST_DIR}/cert.pem" "${DEST_DIR}/keycloak-cert.pem"
    
    # Private keys should be readable by owner and group (for container access)
    chmod 640 "${DEST_DIR}/key.pem" "${DEST_DIR}/keycloak-key.pem"
    
    # Get user IDs for proper ownership
    NGINX_UID=$(docker exec nginx id -u 2>/dev/null || echo "101")  # nginx default UID
    NGINX_GID=$(docker exec nginx id -g 2>/dev/null || echo "101")
    KEYCLOAK_UID=$(docker exec auth.mi-jn.de id -u 2>/dev/null || echo "1000")  # keycloak default UID
    KEYCLOAK_GID=$(docker exec auth.mi-jn.de id -g 2>/dev/null || echo "1000")
    
    # Set ownership for nginx files
    echo "Setting ownership for nginx certificates: ${NGINX_UID}:${NGINX_GID}"
    chown ${NGINX_UID}:${NGINX_GID} "${DEST_DIR}/cert.pem" "${DEST_DIR}/key.pem"
    
    # Set ownership for keycloak files  
    echo "Setting ownership for keycloak certificates: ${KEYCLOAK_UID}:${KEYCLOAK_GID}"
    chown ${KEYCLOAK_UID}:${KEYCLOAK_GID} "${DEST_DIR}/keycloak-cert.pem" "${DEST_DIR}/keycloak-key.pem"
    
    echo "Certificates copied successfully!"
else
    echo "Error: Certificate files not found in ${CERT_DIR}"
    exit 1
fi