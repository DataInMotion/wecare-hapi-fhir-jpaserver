# Let's Encrypt SSL/TLS Certificates

Let's Encrypt is a non-profit certificate authority run by Internet Security Research Group (ISRG) that provides 
X.509 certificates for Transport Layer Security (TLS) encryption at no charge. 

It is the world's largest certificate authority, used by more than 400 million websites, with the goal of all 
websites being secure and using HTTPS.

## Overview

This project includes a secure, automated Let's Encrypt integration with the following features:

- **Automatic Certificate Generation**: Initial certificates are obtained automatically on first startup
- **Automatic Renewal**: Certificates renew automatically twice daily (Let's Encrypt recommendation)
- **Zero Downtime**: Services reload gracefully when certificates are updated
- **Security First**: No Docker socket access required - uses secure file-based triggers
- **Production Ready**: Systemd service integration for reliable operation

## Architecture

The Let's Encrypt integration uses a secure sidecar pattern:

```
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│   Host Monitor      │    │   Certbot Container │    │  Application Stack  │
│                     │    │                     │    │                     │
│ letsencrypt-monitor │◄───│ Creates trigger     │    │ nginx ──────────────│
│ (systemd service)   │    │ files on renewal    │    │ keycloak            │
│                     │    │                     │    │ hapi-fhir           │
│ Reloads services    │    │ No Docker socket    │    │ postgres            │
│ via docker-compose  │    │ access required     │    │ oauth2-proxy        │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
```

## Quick Setup

### 1. Environment Configuration

Add these variables to your `.env` file:

```bash
# Domain Configuration
DOMAIN=fhir.mi-jn.de
KEYCLOAK_HOSTNAME=auth.mi-jn.de

# Let's Encrypt Settings  
LETSENCRYPT_EMAIL=your-email@example.com
```

### 2. Initial Setup

Run the automated setup script:

```bash
./scripts/setup-letsencrypt.sh
```

This script will:
- Validate your configuration
- Start the Docker stack  
- Generate initial certificates
- Set up automatic renewal

### 3. Certificate Monitoring

Choose one of these options for production monitoring:

**Option A: Systemd Service (Recommended)**
```bash
sudo ./scripts/install-systemd-service.sh
```

**Option B: Manual Process (Testing)**
```bash
./scripts/letsencrypt-monitor.sh
```

## How It Works

### Initial Certificate Generation

1. Nginx starts with HTTP-only configuration serving ACME challenges
2. Certbot container performs domain validation via HTTP-01 challenge
3. Certificates are generated and copied to shared volume
4. Trigger files signal the host monitor to reload services
5. Nginx and Keycloak restart with SSL/TLS enabled

### Automatic Renewal

1. Certbot runs renewal checks twice daily (cron schedule)
2. If certificates need renewal (within 30 days of expiry):
   - New certificates are obtained via ACME challenge
   - Certificates are copied to application directories
   - Trigger files are created for the host monitor
3. Host monitor detects triggers and reloads services
4. Applications continue with zero downtime

### Certificate Deployment

Certificates are automatically deployed to:
- `certs/cert.pem` and `certs/key.pem` - For nginx
- `certs/keycloak-cert.pem` and `certs/keycloak-key.pem` - For Keycloak

## Management Commands

### Check Certificate Status
```bash
docker compose -f docker-compose.letsencrypt.yml exec certbot certbot certificates
```

### View Renewal Logs
```bash
# Systemd service logs
journalctl -u letsencrypt-monitor -f

# Certbot container logs  
docker compose -f docker-compose.letsencrypt.yml logs -f certbot
```

### Manual Renewal (Testing)
```bash
# Dry run (testing)
docker compose -f docker-compose.letsencrypt.yml exec certbot certbot renew --dry-run

# Force renewal
docker compose -f docker-compose.letsencrypt.yml exec certbot certbot renew --force-renewal
```

### Service Management
```bash
# Check monitor service status
systemctl status letsencrypt-monitor

# Stop/start monitor service
sudo systemctl stop letsencrypt-monitor
sudo systemctl start letsencrypt-monitor

# Disable auto-start
sudo systemctl disable letsencrypt-monitor
```

## Security Features

### No Docker Socket Access
Unlike many solutions, this implementation doesn't require mounting `/var/run/docker.sock`, eliminating a major security risk.

### Principle of Least Privilege
- Certbot container has minimal permissions
- Host monitor runs with only necessary Docker Compose access
- File-based communication prevents privilege escalation

### Fail-Safe Design
- Failed renewals keep trigger files for retry
- Services continue running with existing certificates on renewal failure
- Comprehensive logging for troubleshooting

## Troubleshooting

### Common Issues

**Domain validation fails:**
- Ensure DNS points to your server
- Check firewall allows HTTP/HTTPS traffic
- Verify nginx is serving ACME challenges

**Certificate generation fails:**
```bash
# Check certbot logs
docker compose -f docker-compose.letsencrypt.yml logs certbot

# Test domain accessibility
curl http://your-domain.com/.well-known/acme-challenge/health-check
```

**Services not reloading:**
```bash
# Check monitor service
systemctl status letsencrypt-monitor

# Check trigger files
ls -la /var/lib/certbot/
```

### Rate Limits

Let's Encrypt has rate limits:
- 50 certificates per domain per week
- 5 failures per account per hostname per hour

For testing, use `--dry-run` flag or the staging environment.

## Migration from Manual Certificates

If you're migrating from manual certificates:

1. Backup existing certificates
2. Update your `.env` with Let's Encrypt settings
3. Run the setup script
4. Verify the new certificates work
5. Install the monitoring service

The system will automatically replace your manual certificates with Let's Encrypt ones.

