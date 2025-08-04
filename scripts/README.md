# Scripts Directory

This directory contains all the management and automation scripts for the HAPI FHIR deployment.

## Let's Encrypt Certificate Management

### `setup-letsencrypt.sh`
**Purpose**: Initial setup and configuration for Let's Encrypt certificates
- Validates environment configuration
- Starts the Docker stack with Let's Encrypt integration
- Initiates certificate generation
- Provides next steps guidance

**Usage**: `./scripts/setup-letsencrypt.sh`

### `letsencrypt-monitor.sh`
**Purpose**: Checks for certificate renewal triggers and reloads services (runs once and exits)
- Checks for trigger files created by certbot
- Safely reloads nginx configuration
- Restarts keycloak when needed
- Designed for cronjob execution

**Usage**: 
- Manual: `./scripts/letsencrypt-monitor.sh`
- Cronjob: Set up with `./scripts/setup-letsencrypt-cron.sh`

### `setup-letsencrypt-cron.sh`
**Purpose**: Sets up certificate monitoring as a cronjob
- Configurable schedule (5min, 15min, hourly, etc.)
- Automatic logging setup
- Management commands provided

**Usage**: `./scripts/setup-letsencrypt-cron.sh`

## User Management

### `add-user.sh`
**Purpose**: Interactive script to add individual users to Keycloak for FHIR API access
- Prompts for user details (username, email, name, password)
- Creates user in Keycloak with proper permissions
- Tests authentication and API access
- Provides detailed feedback

**Usage**: `./scripts/add-user.sh`

### `batch-add-users.sh`
**Purpose**: Add multiple users from CSV file or create example users
- CSV import functionality
- Auto-generates passwords if not provided
- Creates example users for testing
- Saves created user credentials

**Usage**: 
- CSV import: `./scripts/batch-add-users.sh --csv users.csv`
- Examples: `./scripts/batch-add-users.sh --examples`

### `users-example.csv`
**Purpose**: Example CSV template for batch user creation
- Shows proper CSV format
- Includes sample users for different roles
- Can be used as starting point

## API Testing and Access

### `api-access-with-token.sh`
**Purpose**: Interactive script to test FHIR API access with OAuth tokens
- Supports both password grant and client credentials
- Tests token generation and API calls
- Provides usage examples
- Shows complete authentication flow

**Usage**: `./scripts/api-access-with-token.sh`

### `rest-auth-examples.sh`
**Purpose**: Comprehensive OAuth 2.0 authentication examples
- Multiple authentication methods
- Token introspection
- Copy-paste curl examples
- Programming language examples

**Usage**: `./scripts/rest-auth-examples.sh`

### `test-authenticated-api.sh`
**Purpose**: Test script to verify authentication requirements
- Tests unauthenticated access (should fail)
- Verifies bearer token requirements
- Shows interactive login process
- Provides debugging information

**Usage**: `./scripts/test-authenticated-api.sh`

## Security Features

✅ **No Docker Socket Access**: Uses file-based triggers instead of Docker API  
✅ **Principle of Least Privilege**: Minimal permissions required  
✅ **Fail-Safe Design**: Keeps trigger files on failure for retry  
✅ **Comprehensive Logging**: Full audit trail of all operations  
✅ **Graceful Reloads**: Zero-downtime certificate updates  
✅ **Secure Authentication**: All API access requires valid credentials
✅ **User Management**: Controlled access via Keycloak

## Architecture

```
Host System
├── letsencrypt-monitor.sh (cronjob)
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
    └── hapi-fhir: Protected by OAuth 2.0 authentication
```

## Troubleshooting

**Check certificate status:**
```bash
docker compose -f docker-compose.letsencrypt.yml exec certbot certbot certificates
```

**View renewal logs:**
```bash
# Cronjob logs
tail -f /var/log/letsencrypt-monitor.log

# Certbot container logs
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

## Quick Reference

**Setup Commands:**
```bash
# Initial Let's Encrypt setup
./scripts/setup-letsencrypt.sh

# Set up certificate monitoring
./scripts/setup-letsencrypt-cron.sh

# Add a user
./scripts/add-user.sh

# Test API access
./scripts/api-access-with-token.sh
```

**Management Commands:**
```bash
# View cronjobs
crontab -l

# View logs
tail -f /var/log/letsencrypt-monitor.log

# Manual certificate check
./scripts/letsencrypt-monitor.sh

# Test authentication
./scripts/test-authenticated-api.sh
```