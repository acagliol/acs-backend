#!/bin/bash

# Terraform Deployment Script
# Usage: ./scripts/deploy.sh [dev|staging|prod] [--force] [--dry-run]

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

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [ENVIRONMENT] [OPTIONS]

ENVIRONMENTS:
    dev       - Deploy to development environment
    staging   - Deploy to staging environment
    prod      - Deploy to production environment (requires approval)

OPTIONS:
    --force     - Skip confirmation prompts
    --dry-run   - Show what would be deployed without making changes
    --help      - Show this help message

EXAMPLES:
    $0 dev                    # Deploy to dev environment
    $0 staging --dry-run      # Show staging deployment plan
    $0 prod --force           # Deploy to prod (skips confirmation)

EOF
}

# Function to validate environment
validate_environment() {
    local env="$1"
    if [[ ! " ${ENVIRONMENTS[*]} " =~ " ${env} " ]]; then
        print_error "Invalid environment: $env"
        print_error "Valid environments: ${ENVIRONMENTS[*]}"
        exit 1
    fi
}

# Function to check if environment is enabled
check_environment_enabled() {
    local env="$1"
    
    if [[ "$env" == "prod" ]]; then
        print_warning "Production environment deployment - extra care required"
        print_warning "Ensure you have proper approvals before proceeding"
    fi
    
    # Validate that the environment exists in the config
    if ! load_environment_config "$env" >/dev/null 2>&1; then
        print_error "Environment '$env' not found in configuration"
        exit 1
    fi
}

# Function to run preflight checks
run_preflight_checks() {
    local env="$1"
    print_status "Running preflight checks for $env environment..."
    
    # Run the preflight script
    if [[ -f "$SCRIPT_DIR/preflight.sh" ]]; then
        "$SCRIPT_DIR/preflight.sh" "$env"
    else
        print_warning "Preflight script not found, skipping checks"
    fi
}

# Function to backup current state
backup_state() {
    local env="$1"
    print_status "Creating state backup for $env environment..."
    
    if [[ -f "$SCRIPT_DIR/backup-state.sh" ]]; then
        "$SCRIPT_DIR/backup-state.sh" "$env"
    else
        print_warning "Backup script not found, skipping state backup"
    fi
}

# Function to check active gcloud project matches environment
check_gcloud_project() {
    local env="$1"
    local env_config
    env_config=$(load_environment_config "$env")
    local expected_project
    if command -v jq &> /dev/null; then
        expected_project=$(echo "$env_config" | jq -r '.project_id')
    else
        case "$env" in
            dev) expected_project="terraform-anay-dev" ;;
            staging) expected_project="terraform-anay-staging" ;;
            prod) expected_project="terraform-anay-prod" ;;
        esac
    fi
    local active_project
    active_project=$(gcloud config get-value project 2>/dev/null | tr -d '\r\n')
    if [[ "$active_project" != "$expected_project" ]]; then
        print_error "Active gcloud project ($active_project) does not match environment project_id ($expected_project)."
        print_error "Run: gcloud config set project $expected_project"
        exit 1
    fi
}

# Function to deploy to environment
deploy_environment() {
    local env="$1"
    local force="$2"
    local dry_run="$3"
    
    print_status "Deploying to $env environment..."
    
    # Change to project root
    cd "$PROJECT_ROOT"
    
    # Load environment configuration for backend setup
    local env_config
    env_config=$(load_environment_config "$env")
    local bucket_name
    bucket_name=$(echo "$env_config" | jq -r '.bucket_name' 2>/dev/null || echo "terraform-state-$env-anay")
    
    # Initialize Terraform with backend configuration
    if [[ ! -d ".terraform" ]]; then
        print_status "Initializing Terraform..."
        terraform init \
            -backend-config="bucket=$bucket_name" \
            -backend-config="prefix=terraform/state"
    fi
    
    # Validate Terraform configuration
    print_status "Validating Terraform configuration..."
    if ! terraform validate; then
        print_error "Terraform validation failed"
        exit 1
    fi
    
    # Format Terraform code
    print_status "Formatting Terraform code..."
    terraform fmt -recursive
    
    # Show plan
    print_status "Generating deployment plan..."
    terraform plan -var="environment=$env" -out=tfplan
    
    if [[ "$dry_run" == "true" ]]; then
        print_success "Dry run completed. Review the plan above."
        print_status "To apply changes, run: $0 $env"
        exit 0
    fi
    
    # Confirm deployment (unless --force is used)
    if [[ "$force" != "true" ]]; then
        echo
        print_warning "You are about to deploy to the $env environment."
        print_warning "This will modify infrastructure resources."
        
        if [[ "$env" == "prod" ]]; then
            print_warning "⚠️  PRODUCTION DEPLOYMENT - This affects live systems!"
            echo
            read -p "Type 'PRODUCTION' to confirm: " confirmation
            if [[ "$confirmation" != "PRODUCTION" ]]; then
                print_error "Production deployment cancelled"
                exit 1
            fi
        else
            read -p "Do you want to continue? (y/N): " confirmation
            if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
                print_error "Deployment cancelled"
                exit 1
            fi
        fi
    fi
    
    # Apply changes
    print_status "Applying Terraform changes..."
    if terraform apply tfplan; then
        print_success "Deployment to $env completed successfully!"
        
        # Show outputs
        print_status "Deployment outputs:"
        terraform output
    else
        print_error "Deployment to $env failed!"
        print_status "Check the error messages above and fix any issues."
        print_status "You can run './scripts/rollback.sh $env' if needed."
        exit 1
    fi
    
    # Clean up plan file
    rm -f tfplan
}

# Function to check dependencies
check_dependencies() {
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
        exit 1
    fi
}

# Function to load environment configuration
load_environment_config() {
    local env="$1"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    if command -v jq &> /dev/null; then
        local config
        config=$(jq -r ".environments.$env" "$CONFIG_FILE" 2>/dev/null)
        if [[ "$config" == "null" ]] || [[ -z "$config" ]]; then
            print_error "Environment '$env' not found in configuration file"
            exit 1
        fi
        echo "$config"
    else
        print_error "jq is required to parse the configuration file"
        print_error "Please install jq: brew install jq (macOS) or sudo apt-get install jq (Ubuntu/Debian)"
        exit 1
    fi
}

# Main execution
main() {
    local environment=""
    local force=false
    local dry_run=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            dev|staging|prod)
                environment="$1"
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --dry-run)
                dry_run=true
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
    
    # Check dependencies
    check_dependencies
    
    # Validate environment
    validate_environment "$environment"
    
    # Check if environment is enabled
    check_environment_enabled "$environment"
    
    # Check gcloud project matches environment
    check_gcloud_project "$environment"
    
    # Run preflight checks
    run_preflight_checks "$environment"
    
    # Backup current state
    backup_state "$environment"
    
    # Deploy to environment
    deploy_environment "$environment" "$force" "$dry_run"
}

# Run main function with all arguments
main "$@" 