#!/bin/bash

# Batch Add Users to Keycloak
# This script creates multiple users from a CSV file or command line

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
        print_error "Failed to get admin token"
        exit 1
    fi
}

# Function to create a single user
create_single_user() {
    local token="$1"
    local username="$2"
    local email="$3"
    local first_name="$4"
    local last_name="$5"
    local password="$6"
    
    print_info "Creating user: $username"
    
    # Check if user exists
    local existing_user
    existing_user=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM/users?username=$username" \
        -H "Authorization: Bearer $token")
    
    if [ "$(echo "$existing_user" | jq '. | length')" -gt 0 ]; then
        print_warning "User '$username' already exists, skipping"
        return 1
    fi
    
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
    
    if [ "$http_code" = "201" ]; then
        # Get user ID and set password
        local user_id
        user_id=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM/users?username=$username" \
            -H "Authorization: Bearer $token" | jq -r '.[0].id')
        
        # Set password
        local password_payload
        password_payload=$(jq -n \
            --arg password "$password" \
            --argjson temporary false \
            --arg type "password" \
            '{
                type: $type,
                value: $password,
                temporary: $temporary
            }')
        
        curl -s -X PUT "$KEYCLOAK_URL/admin/realms/$REALM/users/$user_id/reset-password" \
            -H "Authorization: Bearer $token" \
            -H 'Content-Type: application/json' \
            -d "$password_payload" >/dev/null
        
        print_success "User '$username' created successfully"
        return 0
    else
        print_error "Failed to create user '$username' (HTTP $http_code)"
        return 1
    fi
}

# Function to generate random password
generate_password() {
    openssl rand -base64 12
}

# Function to create users from CSV
create_from_csv() {
    local token="$1"
    local csv_file="$2"
    
    if [ ! -f "$csv_file" ]; then
        print_error "CSV file not found: $csv_file"
        exit 1
    fi
    
    print_info "Reading users from CSV file: $csv_file"
    
    local line_number=0
    local created_count=0
    local skipped_count=0
    
    while IFS=, read -r username email first_name last_name password || [ -n "$username" ]; do
        line_number=$((line_number + 1))
        
        # Skip header line
        if [ $line_number -eq 1 ] && [ "$username" = "username" ]; then
            continue
        fi
        
        # Skip empty lines
        if [ -z "$username" ]; then
            continue
        fi
        
        # Generate password if not provided
        if [ -z "$password" ]; then
            password=$(generate_password)
        fi
        
        # Remove quotes and whitespace
        username=$(echo "$username" | tr -d '"' | xargs)
        email=$(echo "$email" | tr -d '"' | xargs)
        first_name=$(echo "$first_name" | tr -d '"' | xargs)
        last_name=$(echo "$last_name" | tr -d '"' | xargs)
        password=$(echo "$password" | tr -d '"' | xargs)
        
        if create_single_user "$token" "$username" "$email" "$first_name" "$last_name" "$password"; then
            created_count=$((created_count + 1))
            echo "$username,$email,$first_name,$last_name,$password" >> "users_created_$(date +%Y%m%d_%H%M%S).csv"
        else
            skipped_count=$((skipped_count + 1))
        fi
        
    done < "$csv_file"
    
    echo ""
    print_success "Batch creation completed:"
    echo "  Created: $created_count users"
    echo "  Skipped: $skipped_count users"
    echo "  Credentials saved to: users_created_$(date +%Y%m%d_%H%M%S).csv"
}

# Function to create example users
create_example_users() {
    local token="$1"
    
    print_info "Creating example users..."
    
    local users=(
        "doctor1,doctor1@example.com,Dr. John,Smith,DocPass123!"
        "nurse1,nurse1@example.com,Jane,Doe,NursePass123!"
        "admin1,admin1@example.com,Admin,User,AdminPass123!"
        "researcher1,researcher1@example.com,Research,Analyst,ResearchPass123!"
    )
    
    local created_count=0
    
    for user_data in "${users[@]}"; do
        IFS=, read -r username email first_name last_name password <<< "$user_data"
        
        if create_single_user "$token" "$username" "$email" "$first_name" "$last_name" "$password"; then
            created_count=$((created_count + 1))
            echo "$username,$email,$first_name,$last_name,$password" >> "example_users_$(date +%Y%m%d_%H%M%S).csv"
        fi
    done
    
    print_success "Created $created_count example users"
}

# Main function
main() {
    echo "=== Batch User Creation for Keycloak ==="
    echo "Keycloak URL: $KEYCLOAK_URL"
    echo "Realm: $REALM"
    echo ""
    
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        print_error "jq is required but not installed. Please install jq first."
        exit 1
    fi
    
    # Get admin token
    print_info "Getting admin token..."
    ADMIN_TOKEN=$(get_admin_token)
    print_success "Admin token obtained"
    
    # Determine mode
    if [ "$1" = "--csv" ] && [ -n "$2" ]; then
        create_from_csv "$ADMIN_TOKEN" "$2"
    elif [ "$1" = "--examples" ]; then
        create_example_users "$ADMIN_TOKEN"
    else
        echo "Usage options:"
        echo "  1. Create from CSV file: $0 --csv users.csv"
        echo "  2. Create example users: $0 --examples"
        echo ""
        echo "CSV format: username,email,first_name,last_name,password"
        echo "  - Password column is optional (will be generated if empty)"
        echo "  - First line should be header: username,email,first_name,last_name,password"
        echo ""
        
        read -p "Choose option (1 for CSV, 2 for examples): " OPTION
        
        case $OPTION in
            1)
                read -p "Enter CSV file path: " CSV_FILE
                create_from_csv "$ADMIN_TOKEN" "$CSV_FILE"
                ;;
            2)
                create_example_users "$ADMIN_TOKEN"
                ;;
            *)
                print_error "Invalid option"
                exit 1
                ;;
        esac
    fi
}

# Show help
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Batch User Creation Script for Keycloak"
    echo ""
    echo "Usage:"
    echo "  $0 --csv <file.csv>    Create users from CSV file"
    echo "  $0 --examples          Create example users"
    echo "  $0 --help              Show this help"
    echo ""
    echo "CSV Format:"
    echo "  username,email,first_name,last_name,password"
    echo ""
    echo "Example CSV:"
    echo "  username,email,first_name,last_name,password"
    echo "  john.doe,john@example.com,John,Doe,SecurePass123!"
    echo "  jane.smith,jane@example.com,Jane,Smith,"
    echo ""
    echo "Note: If password is empty, a random password will be generated."
    exit 0
fi

# Run main function
main "$@"