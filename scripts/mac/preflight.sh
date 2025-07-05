#!/bin/bash

# Preflight Check Script
# Usage: ./scripts/preflight.sh [dev|staging|prod]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_FILE="$PROJECT_ROOT/config/environments.json"
ENVIRONMENTS=("dev" "staging" "prod")

# Preflight results
PREFLIGHT_ERRORS=0
PREFLIGHT_WARNINGS=0

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    ((PREFLIGHT_WARNINGS++))
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    ((PREFLIGHT_ERRORS++))
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [ENVIRONMENT]

ENVIRONMENTS:
    dev       - Run preflight checks for development environment
    staging   - Run preflight checks for staging environment
    prod      - Run preflight checks for production environment

EXAMPLES:
    $0 dev      # Run preflight checks for dev
    $0 staging  # Run preflight checks for staging
    $0 prod     # Run preflight checks for prod

EOF
}

# Function to load environment configuration
load_environment_config() {
    local env="$1"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "Configuration file not found: $CONFIG_FILE"
        return 1
    fi
    if command -v jq &> /dev/null; then
        local config
        config=$(jq -r ".environments.$env" "$CONFIG_FILE" 2>/dev/null)
        if [[ "$config" == "null" ]] || [[ -z "$config" ]]; then
            print_error "Environment '$env' not found in configuration file"
            return 1
        fi
        echo "$config"
    else
        print_error "jq is required to parse the configuration file"
        print_error "Please install jq: brew install jq (macOS) or sudo apt-get install jq (Ubuntu/Debian)"
        return 1
    fi
}

# Function to check dependencies
check_dependencies() {
    print_status "Checking required dependencies..."
    
    local missing_deps=()
    
    if ! command -v terraform &> /dev/null; then
        missing_deps+=("terraform")
    fi
    
    if ! command -v gcloud &> /dev/null; then
        missing_deps+=("gcloud")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_error "Please install the missing tools and try again."
        return 1
    fi
    
    # Check Terraform version
    local tf_version=$(terraform version -json | jq -r '.terraform_version' 2>/dev/null || echo "unknown")
    print_status "Terraform version: $tf_version"
    
    # Check gcloud version
    local gcloud_version=$(gcloud version --format="value(google_cloud_sdk_version)" 2>/dev/null || echo "unknown")
    print_status "Google Cloud SDK version: $gcloud_version"
    
    print_success "All required dependencies are available"
    return 0
}

# Function to check Google Cloud authentication
check_gcloud_auth() {
    local env="$1"
    print_status "Checking Google Cloud authentication..."
    
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        print_error "No active Google Cloud authentication found"
        print_status "Run 'gcloud auth login' to authenticate"
        return 1
    fi
    
    local active_account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
    print_status "Active account: $active_account"
    
    # Get project ID from config
    local env_config
    env_config=$(load_environment_config "$env")
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    local project_id
    if command -v jq &> /dev/null; then
        project_id=$(echo "$env_config" | jq -r '.project_id')
    else
        case "$env" in
            dev) project_id="terraform-anay-dev" ;;
            staging) project_id="terraform-anay-staging" ;;
            prod) project_id="terraform-anay-prod" ;;
        esac
    fi
    
    if [[ -n "$project_id" ]]; then
        if gcloud projects describe "$project_id" &>/dev/null; then
            print_success "Access to project $project_id confirmed"
        else
            print_warning "Cannot access project $project_id"
            print_status "You may not have the necessary permissions"
        fi
    fi
    
    print_success "Google Cloud authentication is valid"
    return 0
}

# Function to check environment-specific files
check_environment_files() {
    local env="$1"
    
    print_status "Checking environment configuration for $env..."
    
    # Check if environment exists in config
    if ! load_environment_config "$env" >/dev/null 2>&1; then
        print_error "Environment '$env' not found in configuration"
        return 1
    fi
    
    # Check for required files in project root
    local required_files=("main.tf" "variables.tf")
    for file in "${required_files[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/$file" ]]; then
            print_error "Required file not found: $PROJECT_ROOT/$file"
            return 1
        fi
    done
    
    print_success "Environment configuration is valid"
    return 0
}

# Function to check for sensitive information
check_sensitive_info() {
    local env="$1"
    
    print_status "Checking for sensitive information in $env environment..."
    
    cd "$PROJECT_ROOT"
    
    # Check for hardcoded secrets in main.tf
    if [[ -f "main.tf" ]]; then
        if grep -q -i "password\|secret\|key\|token\|api_key" main.tf; then
            print_error "Sensitive information found in main.tf"
            print_error "Use environment variables or secret management instead"
            return 1
        fi
    fi
    
    print_success "No sensitive information found in configuration files"
    return 0
}

# Function to run preflight checks for an environment
run_preflight_checks() {
    local env="$1"
    
    print_status "Starting preflight checks for $env environment..."
    echo "=================================================="
    
    local all_checks_passed=true
    
    # Run essential preflight checks
    if ! check_dependencies; then
        all_checks_passed=false
    fi
    
    if ! check_gcloud_auth "$env"; then
        all_checks_passed=false
    fi
    
    if ! check_environment_files "$env"; then
        all_checks_passed=false
    fi
    
    if ! check_sensitive_info "$env"; then
        all_checks_passed=false
    fi
    
    echo "=================================================="
    
    if [[ "$all_checks_passed" == "true" ]]; then
        print_success "Preflight checks completed for $env environment"
        return 0
    else
        print_error "Preflight checks failed for $env environment"
        return 1
    fi
}

# Function to print preflight summary
print_preflight_summary() {
    echo
    echo "=================================================="
    echo "PREFLIGHT SUMMARY"
    echo "=================================================="
    echo "Errors: $PREFLIGHT_ERRORS"
    echo "Warnings: $PREFLIGHT_WARNINGS"
    echo "=================================================="
    
    if [[ $PREFLIGHT_ERRORS -eq 0 ]]; then
        print_success "Preflight checks passed! Ready for deployment."
        exit 0
    else
        print_error "Preflight checks failed. Please fix the errors before deployment."
        exit 1
    fi
}

# Main execution
main() {
    local environment=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            dev|staging|prod)
                environment="$1"
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Check if environment is specified
    if [[ -z "$environment" ]]; then
        print_error "Environment not specified"
        show_usage
        exit 1
    fi
    
    # Validate environment
    if [[ ! " ${ENVIRONMENTS[*]} " =~ " ${environment} " ]]; then
        print_error "Invalid environment: $environment"
        print_error "Valid environments: ${ENVIRONMENTS[*]}"
        exit 1
    fi
    
    # Run preflight checks
    run_preflight_checks "$environment"
    
    # Print summary
    print_preflight_summary
}

# Run main function with all arguments
main "$@" 