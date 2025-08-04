# FHIR REST API Authentication

This document explains how to authenticate with the FHIR REST API using OAuth 2.0 through Keycloak.

## Overview

The FHIR server supports OAuth 2.0 authentication with multiple grant types:

- **Password Grant**: Username/password authentication for interactive clients
- **Client Credentials Grant**: Client ID/secret authentication for service-to-service communication
- **Authorization Code Flow**: Web browser-based authentication (handled by oauth2-proxy)

## Configuration

The system is pre-configured with a `fhir-rest` client in Keycloak that supports:

✅ **Direct Access Grants** (Password Grant)  
✅ **Service Accounts** (Client Credentials Grant)  
✅ **Bearer Token Validation** (API Access)  
✅ **FHIR-specific Scopes**  

### Client Configuration

| Setting | Value |
|---------|-------|
| Client ID | `fhir-rest` |
| Client Secret | Check `.env` file or Keycloak admin |
| Access Type | Confidential |
| Grant Types | Password, Client Credentials, Authorization Code |

## Authentication Methods

### 1. Password Grant (Interactive Users)

**Use Case**: Applications where users enter their username/password

```bash
# Get access token
curl -X POST 'https://auth.mi-jn.de:8443/realms/hapi-fhir-dev/protocol/openid-connect/token' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'grant_type=password' \
  -d 'username=YOUR_USERNAME' \
  -d 'password=YOUR_PASSWORD' \
  -d 'client_id=fhir-rest' \
  -d 'client_secret=YOUR_CLIENT_SECRET'
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_in": 300,
  "refresh_expires_in": 1800,
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "scope": "profile email"
}
```

### 2. Client Credentials Grant (Service-to-Service)

**Use Case**: Backend services, automated processes, system integrations

```bash
# Get access token
curl -X POST 'https://auth.mi-jn.de:8443/realms/hapi-fhir-dev/protocol/openid-connect/token' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'grant_type=client_credentials' \
  -d 'client_id=fhir-rest' \
  -d 'client_secret=YOUR_CLIENT_SECRET'
```

### 3. Using Access Tokens

Once you have an access token, include it in the Authorization header:

```bash
# Access FHIR metadata
curl -X GET 'https://fhir.mi-jn.de/fhir/metadata' \
  -H 'Content-Type: application/fhir+json' \
  -H 'Authorization: Bearer YOUR_ACCESS_TOKEN'

# Search for patients
curl -X GET 'https://fhir.mi-jn.de/fhir/Patient' \
  -H 'Content-Type: application/fhir+json' \
  -H 'Authorization: Bearer YOUR_ACCESS_TOKEN'

# Create a new patient
curl -X POST 'https://fhir.mi-jn.de/fhir/Patient' \
  -H 'Content-Type: application/fhir+json' \
  -H 'Authorization: Bearer YOUR_ACCESS_TOKEN' \
  -d '{
    "resourceType": "Patient",
    "name": [{"family": "Doe", "given": ["John"]}],
    "gender": "male"
  }'
```

## Token Management

### Token Expiration

- **Access Token**: 5 minutes (300 seconds)
- **Refresh Token**: 30 minutes (1800 seconds)

### Refresh Tokens

```bash
# Refresh an expired access token
curl -X POST 'https://auth.mi-jn.de:8443/realms/hapi-fhir-dev/protocol/openid-connect/token' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'grant_type=refresh_token' \
  -d 'refresh_token=YOUR_REFRESH_TOKEN' \
  -d 'client_id=fhir-rest' \
  -d 'client_secret=YOUR_CLIENT_SECRET'
```

### Token Introspection

Validate and inspect tokens:

```bash
# Check if token is valid and get claims
curl -X POST 'https://auth.mi-jn.de:8443/realms/hapi-fhir-dev/protocol/openid-connect/token/introspect' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'token=YOUR_ACCESS_TOKEN' \
  -d 'client_id=fhir-rest' \
  -d 'client_secret=YOUR_CLIENT_SECRET'
```

## Programming Examples

### Python Example

```python
import requests
import json

# Configuration
KEYCLOAK_URL = "https://auth.mi-jn.de:8443"
FHIR_URL = "https://fhir.mi-jn.de/fhir"
REALM = "hapi-fhir-dev"
CLIENT_ID = "fhir-rest"
CLIENT_SECRET = "your-client-secret"

def get_access_token(username, password):
    """Get access token using password grant"""
    token_url = f"{KEYCLOAK_URL}/realms/{REALM}/protocol/openid-connect/token"
    
    data = {
        'grant_type': 'password',
        'username': username,
        'password': password,
        'client_id': CLIENT_ID,
        'client_secret': CLIENT_SECRET
    }
    
    response = requests.post(token_url, data=data)
    response.raise_for_status()
    return response.json()['access_token']

def get_client_token():
    """Get access token using client credentials grant"""
    token_url = f"{KEYCLOAK_URL}/realms/{REALM}/protocol/openid-connect/token"
    
    data = {
        'grant_type': 'client_credentials',
        'client_id': CLIENT_ID,
        'client_secret': CLIENT_SECRET
    }
    
    response = requests.post(token_url, data=data)
    response.raise_for_status()
    return response.json()['access_token']

def fhir_request(endpoint, token, method='GET', data=None):
    """Make authenticated FHIR API request"""
    url = f"{FHIR_URL}/{endpoint}"
    headers = {
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/fhir+json'
    }
    
    response = requests.request(method, url, headers=headers, json=data)
    response.raise_for_status()
    return response.json()

# Example usage
if __name__ == "__main__":
    # Get token for service account
    token = get_client_token()
    
    # Get FHIR server metadata
    metadata = fhir_request('metadata', token)
    print(f"FHIR Version: {metadata['fhirVersion']}")
    
    # Search for patients
    patients = fhir_request('Patient', token)
    print(f"Found {patients['total']} patients")
```

### JavaScript/Node.js Example

```javascript
const axios = require('axios');

const config = {
  keycloakUrl: 'https://auth.mi-jn.de:8443',
  fhirUrl: 'https://fhir.mi-jn.de/fhir',
  realm: 'hapi-fhir-dev',
  clientId: 'fhir-rest',
  clientSecret: 'your-client-secret'
};

async function getAccessToken(username, password) {
  const tokenUrl = `${config.keycloakUrl}/realms/${config.realm}/protocol/openid-connect/token`;
  
  const data = new URLSearchParams({
    grant_type: 'password',
    username: username,
    password: password,
    client_id: config.clientId,
    client_secret: config.clientSecret
  });
  
  const response = await axios.post(tokenUrl, data);
  return response.data.access_token;
}

async function getClientToken() {
  const tokenUrl = `${config.keycloakUrl}/realms/${config.realm}/protocol/openid-connect/token`;
  
  const data = new URLSearchParams({
    grant_type: 'client_credentials',
    client_id: config.clientId,
    client_secret: config.clientSecret
  });
  
  const response = await axios.post(tokenUrl, data);
  return response.data.access_token;
}

async function fhirRequest(endpoint, token, method = 'GET', data = null) {
  const url = `${config.fhirUrl}/${endpoint}`;
  const headers = {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/fhir+json'
  };
  
  const response = await axios.request({
    method,
    url,
    headers,
    data
  });
  
  return response.data;
}

// Example usage
async function main() {
  try {
    // Get token for service account
    const token = await getClientToken();
    
    // Get FHIR server metadata
    const metadata = await fhirRequest('metadata', token);
    console.log(`FHIR Version: ${metadata.fhirVersion}`);
    
    // Search for patients
    const patients = await fhirRequest('Patient', token);
    console.log(`Found ${patients.total} patients`);
    
  } catch (error) {
    console.error('Error:', error.response?.data || error.message);
  }
}

main();
```

## Testing Tools

### Interactive Script

Use the provided script to test authentication:

```bash
./scripts/rest-auth-examples.sh
```

### Existing curl.sh Script

Your existing `curl.sh` script demonstrates password grant authentication:

```bash
./curl.sh
```

## Security Best Practices

1. **Use HTTPS**: All authentication requests must use HTTPS
2. **Secure Storage**: Store client secrets securely (environment variables, secrets management)
3. **Token Expiration**: Implement proper token refresh logic
4. **Least Privilege**: Use appropriate scopes for your use case
5. **Client Credentials**: Prefer client credentials grant for service-to-service communication

## Troubleshooting

### Common Issues

**401 Unauthorized**
- Check token expiration
- Verify client credentials
- Ensure token is included in Authorization header

**403 Forbidden**
- Check user permissions in Keycloak
- Verify client scopes
- Check FHIR resource permissions

**Token Validation Errors**
- Verify oauth2-proxy configuration
- Check Keycloak realm settings
- Ensure nginx is properly configured

### Debug Commands

```bash
# Test oauth2-proxy bypass
curl -v -H "Authorization: Bearer YOUR_TOKEN" https://fhir.mi-jn.de/fhir/metadata

# Check token validity
curl -X POST 'https://auth.mi-jn.de:8443/realms/hapi-fhir-dev/protocol/openid-connect/token/introspect' \
  -d 'token=YOUR_TOKEN' \
  -d 'client_id=fhir-rest' \
  -d 'client_secret=YOUR_SECRET'
```

## References

- [OAuth 2.0 RFC](https://tools.ietf.org/html/rfc6749)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [FHIR Security Implementation Guide](https://www.hl7.org/fhir/security.html)
- [oauth2-proxy Documentation](https://oauth2-proxy.github.io/oauth2-proxy/)