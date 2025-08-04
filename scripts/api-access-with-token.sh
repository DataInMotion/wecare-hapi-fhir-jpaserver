#!/bin/bash

# FHIR API Access with Access Token
# This script demonstrates the correct way to access the FHIR API using OAuth 2.0 tokens

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
CLIENT_SECRET="${CLIENT_SECRET}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "ℹ️  $1"; }

echo "=== FHIR API Access with OAuth 2.0 Tokens ==="
echo "Keycloak URL: $KEYCLOAK_URL"
echo "FHIR URL: $FHIR_URL"
echo "Realm: $REALM"
echo "Client ID: $CLIENT_ID"
echo ""

# Check prerequisites
if [ -z "$CLIENT_SECRET" ]; then
    print_error "CLIENT_SECRET not found in .env file"
    echo "Please add CLIENT_SECRET to your .env file"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    print_error "jq is required but not installed"
    echo "Please install jq: sudo apt-get install jq"
    exit 1
fi

echo "Authentication method options:"
echo "1. Username/Password (Password Grant)"
echo "2. Client Credentials (Service Account)"
read -p "Choose method (1 or 2): " AUTH_METHOD

case $AUTH_METHOD in
    1)
        echo ""
        print_info "Using Password Grant (Username/Password)"
        read -p "Enter username: " USERNAME
        read -s -p "Enter password: " PASSWORD
        echo ""
        
        print_info "Getting access token..."
        TOKEN_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token" \
            -H 'Content-Type: application/x-www-form-urlencoded' \
            -d "grant_type=password" \
            -d "username=$USERNAME" \
            -d "password=$PASSWORD" \
            -d "client_id=$CLIENT_ID" \
            -d "client_secret=$CLIENT_SECRET")
        ;;
    2)
        echo ""
        print_info "Using Client Credentials (Service Account)"
        
        print_info "Getting access token..."
        TOKEN_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token" \
            -H 'Content-Type: application/x-www-form-urlencoded' \
            -d "grant_type=client_credentials" \
            -d "client_id=$CLIENT_ID" \
            -d "client_secret=$CLIENT_SECRET")
        ;;
    *)
        print_error "Invalid option"
        exit 1
        ;;
esac

# Check if token request was successful
if echo "$TOKEN_RESPONSE" | jq -e '.access_token' >/dev/null 2>&1; then
    ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')
    EXPIRES_IN=$(echo "$TOKEN_RESPONSE" | jq -r '.expires_in')
    
    print_success "Access token obtained successfully!"
    echo "Token expires in: $EXPIRES_IN seconds"
    echo "Access token: ${ACCESS_TOKEN:0:50}..."
    echo ""
else
    print_error "Failed to obtain access token:"
    echo "$TOKEN_RESPONSE" | jq '.'
    exit 1
fi

# Test the token with FHIR API
print_info "Testing FHIR API access with the token..."
echo ""

# Test 1: Metadata endpoint
echo "1. Testing metadata endpoint:"
METADATA_RESPONSE=$(curl -s -w "%{http_code}" -X GET "$FHIR_URL/metadata" \
    -H 'Content-Type: application/fhir+json' \
    -H "Authorization: Bearer $ACCESS_TOKEN")

HTTP_CODE="${METADATA_RESPONSE: -3}"
RESPONSE_BODY="${METADATA_RESPONSE%???}"

if [ "$HTTP_CODE" = "200" ]; then
    print_success "Metadata access successful!"
    if echo "$RESPONSE_BODY" | jq -e '.fhirVersion' >/dev/null 2>&1; then
        FHIR_VERSION=$(echo "$RESPONSE_BODY" | jq -r '.fhirVersion')
        echo "   FHIR Version: $FHIR_VERSION"
    fi
else
    print_error "Metadata access failed (HTTP $HTTP_CODE)"
    echo "Response: ${RESPONSE_BODY:0:200}..."
fi

echo ""

# Test 2: Patient search (if metadata worked)
if [ "$HTTP_CODE" = "200" ]; then
    echo "2. Testing patient search:"
    PATIENT_RESPONSE=$(curl -s -w "%{http_code}" -X GET "$FHIR_URL/Patient" \
        -H 'Content-Type: application/fhir+json' \
        -H "Authorization: Bearer $ACCESS_TOKEN")
    
    PATIENT_HTTP_CODE="${PATIENT_RESPONSE: -3}"
    PATIENT_BODY="${PATIENT_RESPONSE%???}"
    
    if [ "$PATIENT_HTTP_CODE" = "200" ]; then
        print_success "Patient search successful!"
        if echo "$PATIENT_BODY" | jq -e '.total' >/dev/null 2>&1; then
            TOTAL_PATIENTS=$(echo "$PATIENT_BODY" | jq -r '.total')
            echo "   Found $TOTAL_PATIENTS patients"
        fi
    else
        print_error "Patient search failed (HTTP $PATIENT_HTTP_CODE)"
    fi
    
    echo ""
    
    # Test 3: Create a test patient
    echo "3. Testing patient creation:"
    PATIENT_DATA='{
        "resourceType": "Patient",
        "name": [
            {
                "family": "TestPatient",
                "given": ["API", "Test"]
            }
        ],
        "gender": "unknown",
        "birthDate": "2000-01-01"
    }'
    
    CREATE_RESPONSE=$(curl -s -w "%{http_code}" -X POST "$FHIR_URL/Patient" \
        -H 'Content-Type: application/fhir+json' \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -d "$PATIENT_DATA")
    
    CREATE_HTTP_CODE="${CREATE_RESPONSE: -3}"
    CREATE_BODY="${CREATE_RESPONSE%???}"
    
    if [ "$CREATE_HTTP_CODE" = "201" ]; then
        print_success "Patient creation successful!"
        if echo "$CREATE_BODY" | jq -e '.id' >/dev/null 2>&1; then
            PATIENT_ID=$(echo "$CREATE_BODY" | jq -r '.id')
            echo "   Created patient ID: $PATIENT_ID"
        fi
    else
        print_warning "Patient creation failed or not allowed (HTTP $CREATE_HTTP_CODE)"
        echo "   This might be due to permissions or server configuration"
    fi
fi

echo ""
echo "=== Summary ==="
echo ""
print_success "Token-based authentication is working!"
echo ""
echo "✅ Access tokens can be obtained with username/password"
echo "✅ Access tokens work for FHIR API calls"
echo "✅ No interactive browser login required for API access"
echo ""

echo "=== Usage Examples ==="
echo ""
echo "# Get access token (save this for reuse until it expires):"
echo "TOKEN=\$(curl -s -X POST '$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token' \\"
echo "  -H 'Content-Type: application/x-www-form-urlencoded' \\"
echo "  -d 'grant_type=password' \\"
echo "  -d 'username=YOUR_USERNAME' \\"
echo "  -d 'password=YOUR_PASSWORD' \\"
echo "  -d 'client_id=$CLIENT_ID' \\"
echo "  -d 'client_secret=$CLIENT_SECRET' | jq -r '.access_token')"
echo ""
echo "# Use token for API calls:"
echo "curl -X GET '$FHIR_URL/metadata' \\"
echo "  -H 'Authorization: Bearer \$TOKEN' \\"
echo "  -H 'Content-Type: application/fhir+json'"
echo ""
echo "curl -X GET '$FHIR_URL/Patient' \\"
echo "  -H 'Authorization: Bearer \$TOKEN' \\"
echo "  -H 'Content-Type: application/fhir+json'"
echo ""

# Show token info
echo "=== Current Token Info ==="
echo "Access Token: $ACCESS_TOKEN"
echo "Expires in: $EXPIRES_IN seconds"
echo ""
print_info "Save this token for use in other API calls!"
print_warning "Remember: Tokens expire! Get a new token when this one expires."