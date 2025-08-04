#!/bin/bash

# Add User to Keycloak for FHIR REST API Access
# This script creates new users in Keycloak who can access the FHIR REST API

set -e

# Load environment variables
if [ -f ".env" ]; then
    source .env
fi

# Configuration
KEYCLOAK_URL="${PROTOCOL:-https}://${KEYCLOAK_HOSTNAME:-auth.mi-jn.de}:${KEYCLOAK_PORT:-8443}"
REALM="${KEYCLOAK_REALM:-hapi-fhir-dev}"
ADMIN_USER="${KEYCLOAK_ADMIN:-admin}"
ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-secret}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "ℹ️  $1"; }

# Function to get admin token
get_admin_token() {
    local token_response
    token_response=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
        -H 'Content-Type: application/x-www-form-urlencoded' \
        -d "grant_type=password" \
        -d "username=$ADMIN_USER" \
        -d "password=$ADMIN_PASSWORD" \
        -d "client_id=admin-cli")
    
    if echo "$token_response" | jq -e '.access_token' >/dev/null 2>&1; then
        echo "$token_response" | jq -r '.access_token'
    else
        print_error "Failed to get admin token:"
        echo "$token_response" | jq '.'
        exit 1
    fi
}

# Function to check if user exists
user_exists() {
    local token="$1"
    local username="$2"
    
    local response
    response=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM/users?username=$username" \
        -H "Authorization: Bearer $token" \
        -H 'Content-Type: application/json')
    
    local count
    count=$(echo "$response" | jq '. | length')
    [ "$count" -gt 0 ]
}

# Function to create user
create_user() {
    local token="$1"
    local username="$2"
    local email="$3"
    local first_name="$4"
    local last_name="$5"
    local password="$6"
    local temp_password="$7"
    
    print_info "Creating user: $username"
    
    # Create user payload
    local user_payload
    user_payload=$(jq -n \
        --arg username "$username" \
        --arg email "$email" \
        --arg firstName "$first_name" \
        --arg lastName "$last_name" \
        --argjson enabled true \
        --argjson emailVerified true \
        '{
            username: $username,
            email: $email,
            firstName: $firstName,
            lastName: $lastName,
            enabled: $enabled,
            emailVerified: $emailVerified
        }')
    
    # Create user
    local create_response
    create_response=$(curl -s -w "%{http_code}" -X POST "$KEYCLOAK_URL/admin/realms/$REALM/users" \
        -H "Authorization: Bearer $token" \
        -H 'Content-Type: application/json' \
        -d "$user_payload")
    
    local http_code="${create_response: -3}"
    local response_body="${create_response%???}"
    
    if [ "$http_code" = "201" ]; then
        print_success "User created successfully"
        
        # Set password
        set_user_password "$token" "$username" "$password" "$temp_password"
        
        # Assign roles
        assign_user_roles "$token" "$username"
        
        return 0
    else
        print_error "Failed to create user (HTTP $http_code):"
        echo "$response_body" | jq '.' 2>/dev/null || echo "$response_body"
        return 1
    fi
}

# Function to set user password
set_user_password() {
    local token="$1"
    local username="$2"
    local password="$3"
    local temp_password="$4"
    
    print_info "Setting password for user: $username"
    
    # Get user ID
    local user_id
    user_id=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM/users?username=$username" \
        -H "Authorization: Bearer $token" | jq -r '.[0].id')
    
    if [ "$user_id" = "null" ] || [ -z "$user_id" ]; then
        print_error "Could not find user ID for: $username"
        return 1
    fi
    
    # Set password payload
    local password_payload
    password_payload=$(jq -n \
        --arg password "$password" \
        --argjson temporary "$temp_password" \
        --arg type "password" \
        '{
            type: $type,
            value: $password,
            temporary: $temporary
        }')
    
    # Set password
    local password_response
    password_response=$(curl -s -w "%{http_code}" -X PUT "$KEYCLOAK_URL/admin/realms/$REALM/users/$user_id/reset-password" \
        -H "Authorization: Bearer $token" \
        -H 'Content-Type: application/json' \
        -d "$password_payload")
    
    local http_code="${password_response: -3}"
    
    if [ "$http_code" = "204" ]; then
        if [ "$temp_password" = "true" ]; then
            print_success "Temporary password set (user must change on first login)"
        else
            print_success "Password set successfully"
        fi
    else
        print_error "Failed to set password (HTTP $http_code)"
        return 1
    fi
}

# Function to assign user roles
assign_user_roles() {
    local token="$1"
    local username="$2"
    
    print_info "Assigning roles to user: $username"
    
    # Get user ID
    local user_id
    user_id=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM/users?username=$username" \
        -H "Authorization: Bearer $token" | jq -r '.[0].id')
    
    # Get default roles (this gives basic access)
    local roles_response
    roles_response=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM/roles" \
        -H "Authorization: Bearer $token")
    
    # Assign 'default-roles-hapi-fhir-dev' role if it exists
    local default_role_id
    default_role_id=$(echo "$roles_response" | jq -r '.[] | select(.name=="default-roles-'$REALM'") | .id')
    
    if [ "$default_role_id" != "null" ] && [ -n "$default_role_id" ]; then
        local role_payload
        role_payload=$(jq -n \
            --arg id "$default_role_id" \
            --arg name "default-roles-$REALM" \
            '[{
                id: $id,
                name: $name
            }]')
        
        curl -s -X POST "$KEYCLOAK_URL/admin/realms/$REALM/users/$user_id/role-mappings/realm" \
            -H "Authorization: Bearer $token" \
            -H 'Content-Type: application/json' \
            -d "$role_payload" >/dev/null
    fi
    
    print_success "User roles assigned"
}

# Function to test user authentication
test_user_auth() {
    local username="$1"
    local password="$2"
    
    print_info "Testing authentication for user: $username"
    
    local test_response
    test_response=$(curl -s -X POST "$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token" \
        -H 'Content-Type: application/x-www-form-urlencoded' \
        -d "grant_type=password" \
        -d "username=$username" \
        -d "password=$password" \
        -d "client_id=fhir-rest" \
        -d "client_secret=${CLIENT_SECRET}")
    
    if echo "$test_response" | jq -e '.access_token' >/dev/null 2>&1; then
        print_success "Authentication test successful!"
        local token
        token=$(echo "$test_response" | jq -r '.access_token')
        echo "Access token: ${token:0:50}..."
        
        # Test FHIR API access
        print_info "Testing FHIR API access..."
        local fhir_url="${PROTOCOL:-https}://${DOMAIN:-fhir.mi-jn.de}/fhir"
        local fhir_response
        fhir_response=$(curl -s -X GET "$fhir_url/metadata" \
            -H 'Content-Type: application/fhir+json' \
            -H "Authorization: Bearer $token")
        
        if echo "$fhir_response" | jq -e '.fhirVersion' >/dev/null 2>&1; then
            local fhir_version
            fhir_version=$(echo "$fhir_response" | jq -r '.fhirVersion')
            print_success "FHIR API access successful! (FHIR version: $fhir_version)"
        else
            print_warning "FHIR API access may have issues"
        fi
    else
        print_error "Authentication test failed:"
        echo "$test_response" | jq '.'
    fi
}

# Main script
main() {
    echo "=== Keycloak User Creation Script ==="
    echo "Keycloak URL: $KEYCLOAK_URL"
    echo "Realm: $REALM"
    echo ""
    
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        print_error "jq is required but not installed. Please install jq first."
        exit 1
    fi
    
    # Get user input
    read -p "Enter username: " USERNAME
    read -p "Enter email: " EMAIL
    read -p "Enter first name: " FIRST_NAME
    read -p "Enter last name: " LAST_NAME
    
    # Password options
    echo ""
    echo "Password options:"
    echo "1. Set permanent password"
    echo "2. Set temporary password (user must change on first login)"
    echo "3. Generate random password"
    read -p "Choose option (1-3): " PASSWORD_OPTION
    
    case $PASSWORD_OPTION in
        1)
            read -s -p "Enter password: " PASSWORD
            echo ""
            TEMP_PASSWORD="false"
            ;;
        2)
            read -s -p "Enter temporary password: " PASSWORD
            echo ""
            TEMP_PASSWORD="true"
            ;;
        3)
            PASSWORD=$(openssl rand -base64 12)
            TEMP_PASSWORD="true"
            print_info "Generated password: $PASSWORD"
            ;;
        *)
            print_error "Invalid option"
            exit 1
            ;;
    esac
    
    echo ""
    print_info "Creating user with the following details:"
    echo "Username: $USERNAME"
    echo "Email: $EMAIL"
    echo "First Name: $FIRST_NAME"
    echo "Last Name: $LAST_NAME"
    echo "Temporary Password: $TEMP_PASSWORD"
    echo ""
    
    read -p "Continue? (y/N): " CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        echo "Cancelled."
        exit 0
    fi
    
    # Get admin token
    print_info "Getting admin token..."
    ADMIN_TOKEN=$(get_admin_token)
    print_success "Admin token obtained"
    
    # Check if user already exists
    if user_exists "$ADMIN_TOKEN" "$USERNAME"; then
        print_error "User '$USERNAME' already exists!"
        exit 1
    fi
    
    # Create user
    if create_user "$ADMIN_TOKEN" "$USERNAME" "$EMAIL" "$FIRST_NAME" "$LAST_NAME" "$PASSWORD" "$TEMP_PASSWORD"; then
        echo ""
        print_success "User creation completed!"
        
        # Test authentication
        echo ""
        test_user_auth "$USERNAME" "$PASSWORD"
        
        echo ""
        echo "=== User Summary ==="
        echo "Username: $USERNAME"
        echo "Email: $EMAIL"
        echo "Password: $PASSWORD"
        if [ "$TEMP_PASSWORD" = "true" ]; then
            print_warning "This is a temporary password. User must change it on first login."
        fi
        echo ""
        echo "The user can now:"
        echo "- Access the FHIR REST API using OAuth 2.0"
        echo "- Use password grant authentication"
        echo "- Access FHIR resources based on assigned permissions"
        
    else
        print_error "User creation failed!"
        exit 1
    fi
}

# Show usage if no arguments or help requested
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 [options]"
    echo ""
    echo "This script creates new users in Keycloak for FHIR REST API access."
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "Environment variables (from .env file):"
    echo "  KEYCLOAK_HOSTNAME     Keycloak hostname"
    echo "  KEYCLOAK_PORT         Keycloak port"
    echo "  KEYCLOAK_REALM        Keycloak realm name"
    echo "  KEYCLOAK_ADMIN        Admin username"
    echo "  KEYCLOAK_ADMIN_PASSWORD Admin password"
    echo "  CLIENT_SECRET         FHIR REST client secret"
    echo ""
    echo "Prerequisites:"
    echo "  - jq command-line JSON processor"
    echo "  - Keycloak admin credentials"
    echo "  - Network access to Keycloak server"
    exit 0
fi

# Run main function
main