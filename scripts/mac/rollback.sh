#!/bin/bash

# Terraform Rollback Script
# Usage: ./scripts/rollback.sh [dev|staging|prod] [--force]

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
    dev       - Rollback development environment
    staging   - Rollback staging environment
    prod      - Rollback production environment

OPTIONS:
    --force     - Skip confirmation prompts
    --help      - Show this help message

EXAMPLES:
    $0 dev              # Rollback dev environment
    $0 staging --force  # Rollback staging without confirmation
    $0 prod             # Rollback production (requires confirmation)

WARNING: This script will destroy resources. Use with caution!

EOF
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

# Function to validate environment
validate_environment() {
    local env="$1"
    if [[ ! " ${ENVIRONMENTS[*]} " =~ " ${env} " ]]; then
        print_error "Invalid environment: $env"
        print_error "Valid environments: ${ENVIRONMENTS[*]}"
        exit 1
    fi
}

# Function to check if environment exists
check_environment_exists() {
    local env="$1"
    
    # Check if environment exists in config
    if ! load_environment_config "$env" >/dev/null 2>&1; then
        print_error "Environment '$env' not found in configuration"
        exit 1
    fi
    
    # Check if main.tf exists in project root
    if [[ ! -f "$PROJECT_ROOT/main.tf" ]]; then
        print_error "main.tf not found in project root"
        exit 1
    fi
}

# Function to confirm rollback
confirm_rollback() {
    local env="$1"
    local force="$2"
    
    if [[ "$force" == "true" ]]; then
        return 0
    fi
    
    echo
    print_warning "⚠️  ROLLBACK WARNING ⚠️"
    print_warning "You are about to rollback the $env environment."
    print_warning "This will destroy resources and may cause data loss!"
    echo
    
    if [[ "$env" == "prod" ]]; then
        print_warning "⚠️  PRODUCTION ROLLBACK - This affects live systems!"
        echo
        read -p "Type 'ROLLBACK-PRODUCTION' to confirm: " confirmation
        if [[ "$confirmation" != "ROLLBACK-PRODUCTION" ]]; then
            print_error "Production rollback cancelled"
            exit 1
        fi
    else
        read -p "Do you want to continue with rollback? (y/N): " confirmation
        if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
            print_error "Rollback cancelled"
            exit 1
        fi
    fi
}

# Function to backup current state before rollback
backup_current_state() {
    local env="$1"
    
    print_status "Creating backup of current state before rollback..."
    
    cd "$PROJECT_ROOT"
    
    # Create backup directory
    local backup_dir="$PROJECT_ROOT/backups/$(date +%Y%m%d_%H%M%S)_${env}_rollback"
    mkdir -p "$backup_dir"
    
    # Copy current state files
    if [[ -f "terraform.tfstate" ]]; then
        cp terraform.tfstate "$backup_dir/"
        print_status "State file backed up to: $backup_dir/terraform.tfstate"
    fi
    
    if [[ -f "terraform.tfstate.backup" ]]; then
        cp terraform.tfstate.backup "$backup_dir/"
        print_status "State backup file copied to: $backup_dir/"
    fi
    
    # Copy configuration files
    cp *.tf "$backup_dir/" 2>/dev/null || true
    cp *.tfvars "$backup_dir/" 2>/dev/null || true
    
    # Copy config directory
    if [[ -d "config" ]]; then
        cp -r config "$backup_dir/"
        print_status "Configuration directory backed up"
    fi
    
    print_success "Current state backed up to: $backup_dir"
}

# Function to check for recent deployments
check_recent_deployments() {
    local env="$1"
    
    print_status "Checking for recent deployments..."
    
    cd "$PROJECT_ROOT"
    
    # Check if state file exists and has resources
    if [[ -f "terraform.tfstate" ]]; then
        local resource_count=$(terraform state list 2>/dev/null | wc -l)
        if [[ $resource_count -gt 0 ]]; then
            print_status "Found $resource_count resources in current state"
            
            # List resources
            print_status "Current resources:"
            terraform state list
        else
            print_warning "No resources found in current state"
        fi
    else
        print_warning "No state file found - nothing to rollback"
        return 1
    fi
}

# Function to perform rollback
perform_rollback() {
    local env="$1"
    
    print_status "Performing rollback for $env environment..."
    
    cd "$PROJECT_ROOT"
    
    # Get environment configuration for backend setup
    local env_config
    env_config=$(load_environment_config "$env")
    local bucket_name
    if command -v jq &> /dev/null; then
        bucket_name=$(echo "$env_config" | jq -r '.bucket_name')
    else
        case "$env" in
            dev) bucket_name="terraform-state-dev-anay" ;;
            staging) bucket_name="terraform-state-staging-anay" ;;
            prod) bucket_name="terraform-state-prod-anay" ;;
        esac
    fi
    
    # Initialize Terraform if needed
    if [[ ! -d ".terraform" ]]; then
        print_status "Initializing Terraform..."
        terraform init \
            -backend-config="bucket=$bucket_name" \
            -backend-config="prefix=terraform/state"
    fi
    
    # Show what will be destroyed
    print_status "Generating rollback plan..."
    terraform plan -var="environment=$env" -destroy -out=rollback_plan
    
    # Apply the rollback
    print_status "Applying rollback (destroying resources)..."
    if terraform apply rollback_plan; then
        print_success "Rollback completed successfully!"
        print_status "All resources in $env environment have been destroyed"
    else
        print_error "Rollback failed!"
        print_status "Check the error messages above and try again"
        exit 1
    fi
    
    # Clean up plan file
    rm -f rollback_plan
}

# Function to restore from backup (if needed)
restore_from_backup() {
    local env="$1"
    local backup_dir="$2"
    
    print_status "To restore from backup, run the following commands:"
    echo
    echo "cd $PROJECT_ROOT"
    echo "cp $backup_dir/terraform.tfstate ."
    echo "terraform init -backend-config=\"bucket=$(echo "$(load_environment_config "$env")" | jq -r '.bucket_name' 2>/dev/null || echo "terraform-state-$env-anay")\" -backend-config=\"prefix=terraform/state\""
    echo "terraform plan -var=\"environment=$env\""
    echo "terraform apply -var=\"environment=$env\""
    echo
}

# Function to rollback environment
rollback_environment() {
    local env="$1"
    local force="$2"
    
    print_status "Starting rollback process for $env environment..."
    echo "=================================================="
    
    # Confirm rollback
    confirm_rollback "$env" "$force"
    
    # Backup current state
    backup_current_state "$env"
    
    # Check for recent deployments
    if ! check_recent_deployments "$env"; then
        print_warning "No resources to rollback"
        return 0
    fi
    
    # Perform rollback
    perform_rollback "$env"
    
    echo "=================================================="
    print_success "Rollback completed for $env environment"
    
    # Show restore instructions
    local backup_dir="$PROJECT_ROOT/backups/$(ls -t "$PROJECT_ROOT/backups" | head -1)"
    restore_from_backup "$env" "$backup_dir"
}

# Main execution
main() {
    local environment=""
    local force=false
    
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
    
    # Check if environment exists
    check_environment_exists "$environment"
    
    # Perform rollback
    rollback_environment "$environment" "$force"
}

# Run main function with all arguments
main "$@" 