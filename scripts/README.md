# Let's Encrypt Scripts

This directory contains scripts for secure Let's Encrypt certificate management with automatic renewal.

## Scripts Overview

### `setup-letsencrypt.sh`
**Purpose**: Initial setup and configuration for Let's Encrypt certificates
- Validates environment configuration
- Starts the Docker stack
- Initiates certificate generation
- Provides next steps guidance

**Usage**: `./scripts/setup-letsencrypt.sh`

### `letsencrypt-monitor.sh`
**Purpose**: Monitors for certificate renewal triggers and reloads services
- Watches for trigger files created by certbot
- Safely reloads nginx configuration
- Restarts keycloak when needed
- Provides detailed logging

**Usage**: 
- Manual: `./scripts/letsencrypt-monitor.sh`
- Background: `nohup ./scripts/letsencrypt-monitor.sh &`

### `install-systemd-service.sh`
**Purpose**: Installs the certificate monitor as a systemd service
- Creates systemd service definition
- Enables automatic startup on boot
- Provides service management commands

**Usage**: `sudo ./scripts/install-systemd-service.sh`

## Security Features

✅ **No Docker Socket Access**: Uses file-based triggers instead of Docker API  
✅ **Principle of Least Privilege**: Minimal permissions required  
✅ **Fail-Safe Design**: Keeps trigger files on failure for retry  
✅ **Comprehensive Logging**: Full audit trail of all operations  
✅ **Graceful Reloads**: Zero-downtime certificate updates  

## Architecture

```
Host System
├── letsencrypt-monitor.sh (systemd service)
│   └── Monitors /var/lib/certbot/ for trigger files
│   └── Executes docker compose commands to reload services
│
├── Certbot Container
│   └── Generates/renews certificates
│   └── Creates trigger files in /var/lib/certbot/
│   └── No Docker socket access required
│
└── Application Containers
    └── nginx: Reloaded via docker compose exec
    └── keycloak: Restarted via docker compose restart
```

## Troubleshooting

**Check certificate status:**
```bash
docker compose -f docker-compose.letsencrypt.yml exec certbot certbot certificates
```

**View renewal logs:**
```bash
# If using systemd service
journalctl -u letsencrypt-monitor -f

# If running manually
docker compose -f docker-compose.letsencrypt.yml logs -f certbot
```

**Test nginx configuration:**
```bash
docker compose exec nginx nginx -t
```

**Manual certificate renewal (for testing):**
```bash
docker compose -f docker-compose.letsencrypt.yml exec certbot certbot renew --dry-run
```