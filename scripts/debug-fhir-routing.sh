#!/bin/bash

# Debug FHIR API Routing Issues
# This script helps diagnose 404 and routing problems

set -e

# Load environment variables
if [ -f ".env" ]; then
    source .env
fi

# Configuration
FHIR_URL="${PROTOCOL:-https}://${DOMAIN:-fhir.mi-jn.de}"
HAPI_INTERNAL="http://hapi-fhir:80"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "ℹ️  $1"; }

echo "=== FHIR API Routing Diagnostics ==="
echo "External FHIR URL: $FHIR_URL"
echo ""

# Test 1: Check if FHIR container is running and accessible internally
print_info "Test 1: Checking FHIR container status"
if docker compose ps hapi-fhir | grep -q "Up"; then
    print_success "FHIR container is running"
else
    print_error "FHIR container is not running"
    echo "Run: docker compose up -d hapi-fhir"
    exit 1
fi

# Test 2: Check FHIR server internal endpoints
print_info "Test 2: Testing internal FHIR server endpoints"

# Check root endpoint
echo "Testing internal root endpoint..."
ROOT_RESPONSE=$(docker compose exec hapi-fhir curl -s -w "%{http_code}" http://localhost:80/ || echo "000")
ROOT_HTTP_CODE="${ROOT_RESPONSE: -3}"

if [ "$ROOT_HTTP_CODE" = "200" ] || [ "$ROOT_HTTP_CODE" = "302" ]; then
    print_success "FHIR server root responds (HTTP $ROOT_HTTP_CODE)"
else
    print_warning "FHIR server root issue (HTTP $ROOT_HTTP_CODE)"
fi

# Check FHIR metadata endpoint internally
echo "Testing internal metadata endpoint..."
METADATA_RESPONSE=$(docker compose exec hapi-fhir curl -s -w "%{http_code}" http://localhost:80/fhir/metadata || echo "000")
METADATA_HTTP_CODE="${METADATA_RESPONSE: -3}"

if [ "$METADATA_HTTP_CODE" = "200" ]; then
    print_success "FHIR metadata responds internally (HTTP $METADATA_HTTP_CODE)"
else
    print_error "FHIR metadata fails internally (HTTP $METADATA_HTTP_CODE)"
    echo "This indicates a problem with the FHIR server itself"
fi

# Test 3: Check nginx routing
print_info "Test 3: Checking nginx configuration and routing"

# Check if nginx is running
if docker compose ps nginx | grep -q "Up"; then
    print_success "Nginx container is running"
else
    print_error "Nginx container is not running"
    echo "Run: docker compose up -d nginx"
    exit 1
fi

# Test nginx config
echo "Testing nginx configuration..."
NGINX_CONFIG_TEST=$(docker compose exec nginx nginx -t 2>&1 || echo "failed")
if echo "$NGINX_CONFIG_TEST" | grep -q "successful"; then
    print_success "Nginx configuration is valid"
else
    print_error "Nginx configuration has errors:"
    echo "$NGINX_CONFIG_TEST"
fi

# Test 4: Check external routing (without authentication)
print_info "Test 4: Testing external routing (expect auth redirect)"

# Test external metadata endpoint
echo "Testing external metadata endpoint..."
EXT_METADATA_RESPONSE=$(curl -s -w "%{http_code}" -L "$FHIR_URL/fhir/metadata" || echo "000")
EXT_METADATA_HTTP_CODE="${EXT_METADATA_RESPONSE: -3}"

case $EXT_METADATA_HTTP_CODE in
    200)
        print_success "External metadata accessible (HTTP $EXT_METADATA_HTTP_CODE)"
        ;;
    302|401|403)
        print_success "External metadata correctly redirects for auth (HTTP $EXT_METADATA_HTTP_CODE)"
        ;;
    404)
        print_error "External metadata returns 404 - routing problem!"
        ;;
    *)
        print_warning "External metadata unexpected response (HTTP $EXT_METADATA_HTTP_CODE)"
        ;;
esac

# Test 5: Check FHIR server configuration
print_info "Test 5: Checking FHIR server configuration"

echo "Checking FHIR server logs for errors..."
FHIR_LOGS=$(docker compose logs --tail=20 hapi-fhir 2>/dev/null | grep -i error || echo "No recent errors found")
if [ "$FHIR_LOGS" = "No recent errors found" ]; then
    print_success "No recent errors in FHIR server logs"
else
    print_warning "Found errors in FHIR server logs:"
    echo "$FHIR_LOGS"
fi

# Test 6: Check specific Patient endpoint
print_info "Test 6: Testing Patient endpoint specifically"

# Internal patient endpoint test
echo "Testing internal Patient endpoint..."
PATIENT_RESPONSE=$(docker compose exec hapi-fhir curl -s -w "%{http_code}" http://localhost:80/fhir/Patient || echo "000")
PATIENT_HTTP_CODE="${PATIENT_RESPONSE: -3}"

if [ "$PATIENT_HTTP_CODE" = "200" ]; then
    print_success "Patient endpoint works internally (HTTP $PATIENT_HTTP_CODE)"
else
    print_error "Patient endpoint fails internally (HTTP $PATIENT_HTTP_CODE)"
fi

# Test 7: Nginx logs analysis
print_info "Test 7: Checking nginx logs for routing issues"

echo "Recent nginx access logs:"
docker compose logs --tail=10 nginx 2>/dev/null | grep -E "(GET|POST|PUT|DELETE)" || echo "No recent access logs found"

echo ""
echo "Recent nginx error logs:"
docker compose logs --tail=10 nginx 2>/dev/null | grep -i error || echo "No recent error logs found"

# Test 8: Show useful debugging commands
echo ""
print_info "Useful debugging commands:"
echo ""
echo "# Check all container status:"
echo "docker compose ps"
echo ""
echo "# Check FHIR server logs:"
echo "docker compose logs -f hapi-fhir"
echo ""
echo "# Check nginx logs:"
echo "docker compose logs -f nginx"
echo ""
echo "# Test internal FHIR endpoints:"
echo "docker compose exec hapi-fhir curl -v http://localhost:80/fhir/metadata"
echo ""
echo "# Test nginx proxy:"
echo "docker compose exec nginx curl -v http://hapi-fhir:80/fhir/metadata"
echo ""

# Test 9: Show browser-based debugging
print_info "Browser debugging steps:"
echo ""
echo "1. Open browser developer tools (F12)"
echo "2. Go to Network tab"
echo "3. Try accessing: $FHIR_URL/fhir/Patient"
echo "4. Check the network request details:"
echo "   - Status code"
echo "   - Response headers"
echo "   - Actual URL being requested"
echo "5. Look for redirects or proxy errors"
echo ""

print_warning "If you're getting 404 after successful login, the issue is likely:"
echo "- FHIR server not responding on the expected path"
echo "- nginx proxy configuration error"
echo "- FHIR server base URL misconfiguration"