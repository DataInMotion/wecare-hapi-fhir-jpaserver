# WeCaRe HAPI FHIR Server

A production-ready HAPI FHIR JPA Server deployment with OAuth 2.0 authentication, Let's Encrypt SSL certificates, and comprehensive user management.

## Features

✅ **HAPI FHIR JPA Server** (v8.0.0) - Full-featured FHIR R4/R5 server  
✅ **OAuth 2.0 Authentication** - Secure API access via Keycloak  
✅ **Automated SSL Certificates** - Let's Encrypt with automatic renewal  
✅ **User Management** - Scripts for adding and managing API users  
✅ **Production Ready** - Docker Compose deployment with monitoring  
✅ **Custom Theming** - WeCaRe branding for both FHIR and Keycloak interfaces  

## Quick Start

### Prerequisites
- Docker and Docker Compose
- Domain names pointing to your server
- Basic Linux command line knowledge

### 1. Initial Setup
```bash
# Clone the repository
git clone <repository-url>
cd wecare-hapi-fhir-jpaserver

# Configure environment
cp .env.letsencrypt.example .env
# Edit .env with your domains and settings

# Start the basic stack
docker compose up -d
```

### 2. Set Up SSL Certificates
```bash
# Automated Let's Encrypt setup
./scripts/setup-letsencrypt.sh

# Set up certificate monitoring
./scripts/setup-letsencrypt-cron.sh
```

### 3. Add Users
```bash
# Add individual users
./scripts/add-user.sh

# Or add multiple users from CSV
./scripts/batch-add-users.sh --csv users.csv
```

### 4. Test API Access
```bash
# Test authentication and API access
./scripts/api-access-with-token.sh
```

## Project Structure

```
├── services/           # Docker service definitions
│   ├── hapi-fhir/     # FHIR server container
│   ├── keycloak/      # Identity provider
│   ├── nginx/         # Reverse proxy
│   ├── certbot/       # SSL certificate management
│   └── ...
├── scripts/           # Management and automation scripts
├── docs/              # Detailed documentation
├── custom-*-theme/    # UI customizations
├── development-realm.json  # Keycloak realm configuration
└── docker-compose*.yml     # Docker Compose configurations
```

## Base Project Credits

This project builds upon excellent work from the FHIR community:

- **Base Project**: [HAPI FHIR JPA Server Starter](https://github.com/hapifhir/hapi-fhir-jpaserver-starter)
- **OAuth Integration**: Based on [Rob Ferguson's guides](https://rob-ferguson.me/getting-started-with-hapi-fhir/)
- **Reference Implementation**: [HAPI FHIR AU](https://github.com/Robinyo/hapi-fhir-au/)



## Architecture

The system consists of several interconnected services:

- **nginx** - Reverse proxy with SSL termination and authentication
- **hapi-fhir** - FHIR server (main application)
- **keycloak** - Identity provider and OAuth 2.0 server
- **oauth2-proxy** - OAuth 2.0 authentication proxy
- **postgres** - Database for FHIR data and Keycloak
- **redis** - Session storage for oauth2-proxy
- **certbot** - SSL certificate generation and renewal

## Configuration

### Environment Variables

Copy `.env.letsencrypt.example` to `.env` and configure:

```bash
# Domain Configuration
DOMAIN=fhir.your-domain.com
KEYCLOAK_HOSTNAME=auth.your-domain.com

# Let's Encrypt
LETSENCRYPT_EMAIL=your-email@example.com

# Database
POSTGRES_DB=hapi-fhir
POSTGRES_USER=admin
POSTGRES_PASSWORD=your-secure-password

# Keycloak
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=your-admin-password

# OAuth 2.0
CLIENT_ID=fhir-rest
CLIENT_SECRET=your-client-secret
```

### Keycloak Realm Management

The installation includes development realm configuration in `development-realm.json`.

**Import realm (initial setup):**
```bash
docker compose stop
docker compose -f docker-compose-keycloak-realm-import.yml up -d
docker compose -f docker-compose-keycloak-realm-import.yml stop
docker compose -f docker-compose-keycloak-realm-import.yml down
docker compose up -d
```

**Export realm changes:**
```bash
docker compose stop
docker compose -f docker-compose-keycloak-realm-export.yml up -d
docker compose -f docker-compose-keycloak-realm-export.yml stop
docker compose -f docker-compose-keycloak-realm-export.yml down
docker compose up -d
```

## API Access

### Authentication Flow

1. **Get Access Token** - Authenticate with username/password to get OAuth token
2. **API Requests** - Include token in `Authorization: Bearer` header
3. **Token Refresh** - Get new tokens when they expire

### Example Usage

```bash
# Get access token
TOKEN=$(curl -s -X POST 'https://auth.your-domain.com:8443/realms/hapi-fhir-dev/protocol/openid-connect/token' \
  -d 'grant_type=password' \
  -d 'username=your-username' \
  -d 'password=your-password' \
  -d 'client_id=fhir-rest' \
  -d 'client_secret=your-client-secret' | jq -r '.access_token')

# Use token for API calls
curl -X GET 'https://fhir.your-domain.com/fhir/Patient' \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/fhir+json'
```

## SSL Certificates

### Development
Use [mkcert](docs/developer/mkcert.md) for local development certificates.

### Production
Use [Let's Encrypt](docs/developer/lets-encrypt.md) for production SSL certificates with automatic renewal.

## Customization

- **FHIR Web Interface**: Customize in `custom-hapi-theme/`
- **Keycloak Theme**: WeCaRe theme in `custom-keycloak-theme/`
- **Configuration**: Modify `hapi.application.yaml` for FHIR server settings

## Management Scripts

All management tasks are handled via scripts in the `scripts/` directory:

```bash
# SSL Certificate Management
./scripts/setup-letsencrypt.sh           # Initial SSL setup
./scripts/setup-letsencrypt-cron.sh      # Certificate monitoring
./scripts/letsencrypt-monitor.sh         # Manual certificate check

# User Management
./scripts/add-user.sh                    # Add single user
./scripts/batch-add-users.sh             # Add multiple users

# Testing and Validation
./scripts/api-access-with-token.sh       # Test OAuth flow
./scripts/test-authenticated-api.sh      # Verify security
./scripts/rest-auth-examples.sh          # Authentication examples
```

## Documentation

- **[CLAUDE.md](CLAUDE.md)** - Developer guide and architecture overview
- **[docs/developer/](docs/developer/)** - Detailed technical documentation
- **[scripts/README.md](scripts/README.md)** - Complete script reference

## Security Features

🔒 **Authentication Required** - All API access requires valid credentials  
🔒 **OAuth 2.0 Flow** - Industry standard authentication  
🔒 **SSL/TLS Encryption** - All traffic encrypted with Let's Encrypt certificates  
🔒 **User Management** - Controlled access via Keycloak  
🔒 **Secure Defaults** - Production-ready security configuration  

## Monitoring and Logs

```bash
# Service logs
docker compose logs -f [service-name]

# Certificate renewal logs
tail -f /var/log/letsencrypt-monitor.log

# System status
docker compose ps
```

## Support

For detailed technical information, see:
- [CLAUDE.md](CLAUDE.md) - Complete development guide
- [docs/developer/](docs/developer/) - Technical documentation
- [scripts/README.md](scripts/README.md) - Script reference
