#!/bin/bash

# Test Audit Logging Script
# This script tests the FHIR audit logging functionality

set -e

# Load environment variables
if [ -f ".env" ]; then
    source .env
fi

# Configuration
FHIR_URL="${PROTOCOL:-https}://${DOMAIN:-fhir.mi-jn.de}"
KEYCLOAK_URL="https://${KEYCLOAK_HOSTNAME:-auth.mi-jn.de}:8443"
AUDIT_LOG_FILE="./logs/audit/audit.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "ℹ️  $1"; }

echo "=== FHIR Audit Logging Test ==="
echo "FHIR URL: $FHIR_URL"
echo "Audit Log: $AUDIT_LOG_FILE"
echo ""

# Check if audit log directory exists
if [ ! -d "./logs/audit" ]; then
    print_error "Audit log directory doesn't exist. Creating it..."
    mkdir -p ./logs/audit
fi

# Function to get access token
get_access_token() {
    local username="$1"
    local password="$2"
    
    local token_response=$(curl -s -X POST "$KEYCLOAK_URL/realms/hapi-fhir-dev/protocol/openid-connect/token" \
        -d "grant_type=password" \
        -d "username=$username" \
        -d "password=$password" \
        -d "client_id=${CLIENT_ID:-fhir-rest}" \
        -d "client_secret=${CLIENT_SECRET:-your-client-secret}" \
        2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$token_response" ]; then
        echo "$token_response" | jq -r '.access_token' 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# Function to make authenticated FHIR request
make_fhir_request() {
    local method="$1"
    local endpoint="$2"
    local token="$3"
    local description="$4"
    
    print_info "$description"
    
    local response=$(curl -s -w "%{http_code}" -X "$method" \
        "$FHIR_URL/fhir$endpoint" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/fhir+json" \
        -H "Accept: application/fhir+json" \
        2>/dev/null)
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        print_success "Request successful (HTTP $http_code)"
    else
        print_warning "Request returned HTTP $http_code"
    fi
    
    return 0
}

# Test 1: Check Docker services are running
print_info "Test 1: Checking Docker services"
if docker compose ps hapi-fhir | grep -q "Up"; then
    print_success "HAPI FHIR service is running"
else
    print_error "HAPI FHIR service is not running"
    print_info "Please start services with: docker compose up -d"
    exit 1
fi

# Test 2: Get a test user token
print_info "Test 2: Getting authentication token"
print_info "Please enter test user credentials:"
read -p "Username: " TEST_USERNAME
read -s -p "Password: " TEST_PASSWORD
echo ""

ACCESS_TOKEN=$(get_access_token "$TEST_USERNAME" "$TEST_PASSWORD")

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
    print_error "Failed to get access token. Please check credentials and Keycloak configuration."
    print_info "You can create a test user with: ./scripts/add-user.sh"
    exit 1
else
    print_success "Access token obtained successfully"
fi

# Clear previous audit logs for clean testing
if [ -f "$AUDIT_LOG_FILE" ]; then
    echo "=== Previous audit entries ===" > "${AUDIT_LOG_FILE}.backup.$(date +%s)"
    cat "$AUDIT_LOG_FILE" >> "${AUDIT_LOG_FILE}.backup.$(date +%s)" 2>/dev/null || true
    > "$AUDIT_LOG_FILE"
    print_info "Cleared previous audit log for clean testing"
fi

# Test 3: Make various FHIR requests to test audit logging
print_info "Test 3: Making test FHIR requests"

# Wait a moment to ensure services are ready
sleep 2

# Test different types of requests
make_fhir_request "GET" "/metadata" "$ACCESS_TOKEN" "Testing metadata endpoint"
sleep 1

make_fhir_request "GET" "/Patient" "$ACCESS_TOKEN" "Testing Patient search"
sleep 1

make_fhir_request "GET" "/Observation?_count=5" "$ACCESS_TOKEN" "Testing Observation search with parameters"
sleep 1

make_fhir_request "GET" "/Organization" "$ACCESS_TOKEN" "Testing Organization search"
sleep 1

# Test 4: Check audit log entries
print_info "Test 4: Checking audit log entries"

# Wait a moment for logs to be written
sleep 3

if [ -f "$AUDIT_LOG_FILE" ]; then
    AUDIT_ENTRIES=$(wc -l < "$AUDIT_LOG_FILE" 2>/dev/null || echo "0")
    
    if [ "$AUDIT_ENTRIES" -gt 0 ]; then
        print_success "Found $AUDIT_ENTRIES audit log entries"
        
        echo ""
        print_info "Recent audit log entries:"
        echo "========================="
        tail -n 10 "$AUDIT_LOG_FILE" | while IFS= read -r line; do
            if [ -n "$line" ]; then
                # Pretty print JSON if possible
                echo "$line" | jq . 2>/dev/null || echo "$line"
                echo "---"
            fi
        done
        
        # Check if username is being logged
        if grep -q "\"username\":\"$TEST_USERNAME\"" "$AUDIT_LOG_FILE" 2>/dev/null; then
            print_success "Username '$TEST_USERNAME' is being logged correctly"
        else
            print_warning "Username might not be logged correctly"
        fi
        
        # Check for different event types
        REQUEST_EVENTS=$(grep -c "\"event_type\":\"FHIR_REQUEST\"" "$AUDIT_LOG_FILE" 2>/dev/null || echo "0")
        RESPONSE_EVENTS=$(grep -c "\"event_type\":\"FHIR_RESPONSE\"" "$AUDIT_LOG_FILE" 2>/dev/null || echo "0")
        
        print_info "Found $REQUEST_EVENTS request events and $RESPONSE_EVENTS response events"
        
    else
        print_error "No audit log entries found!"
        print_info "Check Docker logs: docker compose logs hapi-fhir"
        print_info "Check if interceptor is loaded: docker compose logs hapi-fhir | grep -i audit"
    fi
else
    print_error "Audit log file not found: $AUDIT_LOG_FILE"
    print_info "Check if the audit log directory is mounted correctly in docker-compose.yml"
fi

# Test 5: Validate log format
print_info "Test 5: Validating log format"

if [ -f "$AUDIT_LOG_FILE" ] && [ -s "$AUDIT_LOG_FILE" ]; then
    # Check if logs are valid JSON
    VALID_JSON_COUNT=0
    TOTAL_LINES=0
    
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            TOTAL_LINES=$((TOTAL_LINES + 1))
            if echo "$line" | jq . >/dev/null 2>&1; then
                VALID_JSON_COUNT=$((VALID_JSON_COUNT + 1))
            fi
        fi
    done < "$AUDIT_LOG_FILE"
    
    if [ "$VALID_JSON_COUNT" -eq "$TOTAL_LINES" ] && [ "$TOTAL_LINES" -gt 0 ]; then
        print_success "All $TOTAL_LINES audit log entries are valid JSON"
    else
        print_warning "$VALID_JSON_COUNT out of $TOTAL_LINES audit log entries are valid JSON"
    fi
    
    # Check for required fields
    REQUIRED_FIELDS=("timestamp" "event_type" "username" "method" "request_path")
    for field in "${REQUIRED_FIELDS[@]}"; do
        if grep -q "\"$field\":" "$AUDIT_LOG_FILE"; then
            print_success "Field '$field' is present in audit logs"
        else
            print_warning "Field '$field' is missing from audit logs"
        fi
    done
fi

echo ""
print_info "Audit logging test completed!"
print_info "You can view the full audit log with: tail -f $AUDIT_LOG_FILE | jq ."
print_info "Or view raw logs with: tail -f $AUDIT_LOG_FILE"