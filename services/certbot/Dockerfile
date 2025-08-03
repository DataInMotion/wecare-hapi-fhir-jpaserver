FROM certbot/certbot:latest

# Install necessary tools for automation
RUN apk add --no-cache \
    dcron \
    bash \
    curl \
    shadow

# Create directories for renewal scripts and triggers
RUN mkdir -p /opt/certbot-hooks /var/lib/certbot

# Create certbot user for better security
RUN addgroup -g 1000 certbot && \
    adduser -D -u 1000 -G certbot -h /home/certbot certbot

# Copy renewal scripts
COPY scripts/ /opt/certbot-hooks/
RUN chmod +x /opt/certbot-hooks/*.sh

# Set up cron for automatic renewal (runs twice daily as recommended by Let's Encrypt)
# Note: Running as root is required for certbot and file operations
RUN echo "0 2,14 * * * /opt/certbot-hooks/renew.sh 2>&1" > /etc/crontabs/root

# Create entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set proper ownership for directories that certbot needs to write to
RUN chown -R root:root /etc/letsencrypt /var/lib/letsencrypt /var/log/letsencrypt /opt/certbot-hooks /var/lib/certbot

ENTRYPOINT ["/entrypoint.sh"]
CMD ["crond", "-f", "-l", "2"]