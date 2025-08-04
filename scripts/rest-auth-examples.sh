#!/bin/bash

# FHIR REST API Authentication Examples
# This script demonstrates different ways to authenticate with the FHIR API

set -e

# Load environment variables
if [ -f ".env" ]; then
    source .env
fi

# Configuration
KEYCLOAK_URL="${PROTOCOL:-https}://${KEYCLOAK_HOSTNAME:-auth.mi-jn.de}:${KEYCLOAK_PORT:-8443}"
FHIR_URL="${PROTOCOL:-https}://${DOMAIN:-fhir.mi-jn.de}/fhir"
REALM="${KEYCLOAK_REALM:-hapi-fhir-dev}"
CLIENT_ID="${CLIENT_ID:-fhir-rest}"
CLIENT_SECRET="${CLIENT_SECRET:-uzOr2tn7wMaza8Qp00A7c3f9SxvmLfsx}"

echo "=== FHIR REST API Authentication Examples ==="
echo "Keycloak URL: $KEYCLOAK_URL"
echo "FHIR URL: $FHIR_URL"
echo "Realm: $REALM"
echo "Client ID: $CLIENT_ID"
echo ""

# Method 1: Password Grant (Resource Owner Password Credentials)
echo "1. Password Grant Authentication"
echo "================================"
echo "This method uses username/password to get an access token"
echo ""

read -p "Enter username: " USERNAME
read -s -p "Enter password: " PASSWORD
echo ""

echo "Getting access token with password grant..."
PASSWORD_TOKEN_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "grant_type=password" \
  -d "username=$USERNAME" \
  -d "password=$PASSWORD" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET")

if echo "$PASSWORD_TOKEN_RESPONSE" | jq -e '.access_token' >/dev/null 2>&1; then
    PASSWORD_ACCESS_TOKEN=$(echo "$PASSWORD_TOKEN_RESPONSE" | jq -r '.access_token')
    echo "✅ Password grant successful!"
    echo "Access token: ${PASSWORD_ACCESS_TOKEN:0:50}..."
    
    echo ""
    echo "Testing FHIR metadata endpoint with password grant token:"
    curl -s -X GET "$FHIR_URL/metadata" \
        -H 'Content-Type: application/fhir+json' \
        -H "Authorization: Bearer $PASSWORD_ACCESS_TOKEN" | jq '.fhirVersion // "Request successful"'
else
    echo "❌ Password grant failed:"
    echo "$PASSWORD_TOKEN_RESPONSE" | jq '.'
fi

echo ""
echo "----------------------------------------"
echo ""

# Method 2: Client Credentials Grant
echo "2. Client Credentials Grant Authentication"
echo "=========================================="
echo "This method uses client ID/secret for service-to-service authentication"
echo ""

echo "Getting access token with client credentials grant..."
CLIENT_TOKEN_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET")

if echo "$CLIENT_TOKEN_RESPONSE" | jq -e '.access_token' >/dev/null 2>&1; then
    CLIENT_ACCESS_TOKEN=$(echo "$CLIENT_TOKEN_RESPONSE" | jq -r '.access_token')
    echo "✅ Client credentials grant successful!"
    echo "Access token: ${CLIENT_ACCESS_TOKEN:0:50}..."
    
    echo ""
    echo "Testing FHIR metadata endpoint with client credentials token:"
    curl -s -X GET "$FHIR_URL/metadata" \
        -H 'Content-Type: application/fhir+json' \
        -H "Authorization: Bearer $CLIENT_ACCESS_TOKEN" | jq '.fhirVersion // "Request successful"'
else
    echo "❌ Client credentials grant failed:"
    echo "$CLIENT_TOKEN_RESPONSE" | jq '.'
fi

echo ""
echo "----------------------------------------"
echo ""

# Method 3: Token Introspection Example
echo "3. Token Introspection"
echo "======================"
echo "This shows how to validate and inspect tokens"
echo ""

if [ -n "$PASSWORD_ACCESS_TOKEN" ]; then
    echo "Introspecting password grant token..."
    curl -s -X POST "$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token/introspect" \
        -H 'Content-Type: application/x-www-form-urlencoded' \
        -d "token=$PASSWORD_ACCESS_TOKEN" \
        -d "client_id=$CLIENT_ID" \
        -d "client_secret=$CLIENT_SECRET" | jq '.'
fi

echo ""
echo "=== Complete Example Curl Commands ==="
echo ""
echo "# Password Grant:"
echo "curl -X POST '$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token' \\"
echo "  -H 'Content-Type: application/x-www-form-urlencoded' \\"
echo "  -d 'grant_type=password' \\"
echo "  -d 'username=YOUR_USERNAME' \\"
echo "  -d 'password=YOUR_PASSWORD' \\"
echo "  -d 'client_id=$CLIENT_ID' \\"
echo "  -d 'client_secret=$CLIENT_SECRET'"
echo ""
echo "# Client Credentials Grant:"
echo "curl -X POST '$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token' \\"
echo "  -H 'Content-Type: application/x-www-form-urlencoded' \\"
echo "  -d 'grant_type=client_credentials' \\"
echo "  -d 'client_id=$CLIENT_ID' \\"
echo "  -d 'client_secret=$CLIENT_SECRET'"
echo ""
echo "# Using token to access FHIR API:"
echo "curl -X GET '$FHIR_URL/metadata' \\"
echo "  -H 'Content-Type: application/fhir+json' \\"
echo "  -H 'Authorization: Bearer YOUR_ACCESS_TOKEN'"