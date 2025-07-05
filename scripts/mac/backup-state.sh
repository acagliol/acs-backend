#!/bin/bash

# Terraform State Backup Script
# Usage: ./scripts/backup-state.sh [dev|staging|prod]

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
    dev       - Backup development environment state
    staging   - Backup staging environment state
    prod      - Backup production environment state
    all       - Backup all environments

OPTIONS:
    --cleanup  - Clean up old backups (keep last 5)
    --help     - Show this help message

EXAMPLES:
    $0 dev              # Backup dev environment state
    $0 all --cleanup    # Backup all environments and clean up old backups
    $0 prod             # Backup production environment state

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

# Function to validate environment
validate_environment() {
    local env="$1"
    if [[ ! " ${ENVIRONMENTS[*]} " =~ " ${env} " ]]; then
        print_error "Invalid environment: $env"
        print_error "Valid environments: ${ENVIRONMENTS[*]}"
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

# Function to check if environment exists
check_environment_exists() {
    local env="$1"
    
    # Check if environment exists in config
    if ! load_environment_config "$env" >/dev/null 2>&1; then
        print_error "Environment '$env' not found in configuration"
        return 1
    fi
    
    # Check if main.tf exists in project root
    if [[ ! -f "$PROJECT_ROOT/main.tf" ]]; then
        print_error "main.tf not found in project root"
        return 1
    fi
    
    return 0
}

# Function to create backup directory
create_backup_directory() {
    local env="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="$PROJECT_ROOT/backups/${timestamp}_${env}_backup"
    
    mkdir -p "$backup_dir"
    echo "$backup_dir"
}

# Function to backup state files
backup_state_files() {
    local env="$1"
    local backup_dir="$2"
    
    print_status "Backing up state files for $env environment..."
    
    cd "$PROJECT_ROOT"
    
    # Backup terraform.tfstate
    if [[ -f "terraform.tfstate" ]]; then
        cp terraform.tfstate "$backup_dir/"
        print_status "✓ terraform.tfstate backed up"
    else
        print_warning "No terraform.tfstate found"
    fi
    
    # Backup terraform.tfstate.backup
    if [[ -f "terraform.tfstate.backup" ]]; then
        cp terraform.tfstate.backup "$backup_dir/"
        print_status "✓ terraform.tfstate.backup backed up"
    fi
    
    # Backup .terraform.lock.hcl
    if [[ -f ".terraform.lock.hcl" ]]; then
        cp .terraform.lock.hcl "$backup_dir/"
        print_status "✓ .terraform.lock.hcl backed up"
    fi
}

# Function to backup configuration files
backup_config_files() {
    local env="$1"
    local backup_dir="$2"
    
    print_status "Backing up configuration files for $env environment..."
    
    cd "$PROJECT_ROOT"
    
    # Backup all .tf files
    if ls *.tf 1> /dev/null 2>&1; then
        cp *.tf "$backup_dir/"
        print_status "✓ Terraform configuration files backed up"
    fi
    
    # Backup .tfvars files
    if ls *.tfvars 1> /dev/null 2>&1; then
        cp *.tfvars "$backup_dir/"
        print_status "✓ Terraform variable files backed up"
    fi
    
    # Backup other configuration files
    local config_files=(".tflint.hcl" "versions.tf" "backend.tf")
    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            cp "$file" "$backup_dir/"
            print_status "✓ $file backed up"
        fi
    done
    
    # Backup config directory
    if [[ -d "config" ]]; then
        cp -r config "$backup_dir/"
        print_status "✓ Configuration directory backed up"
    fi
}

# Function to create backup metadata
create_backup_metadata() {
    local env="$1"
    local backup_dir="$2"
    
    print_status "Creating backup metadata..."
    
    # Create metadata file
    cat > "$backup_dir/backup_metadata.txt" << EOF
Backup Information
==================

Environment: $env
Backup Date: $(date)
Backup Time: $(date +%H:%M:%S)
Backup Directory: $backup_dir

System Information:
- Terraform Version: $(terraform version -json | jq -r '.terraform_version' 2>/dev/null || echo "unknown")
- Google Cloud SDK Version: $(gcloud version --format="value(google_cloud_sdk_version)" 2>/dev/null || echo "unknown")
- Operating System: $(uname -s)
- Hostname: $(hostname)

Backup Contents:
- State files
- Configuration files
- Variable files
- Lock files

EOF
    
    print_status "✓ Backup metadata created"
}

# Function to verify backup integrity
verify_backup_integrity() {
    local backup_dir="$1"
    
    print_status "Verifying backup integrity..."
    
    # Check if essential files are present
    local missing_files=()
    
    if [[ ! -f "$backup_dir/backup_metadata.txt" ]]; then
        missing_files+=("backup_metadata.txt")
    fi
    
    # Check for at least one .tf file
    if ! ls "$backup_dir"/*.tf 1> /dev/null 2>&1; then
        missing_files+=("*.tf files")
    fi
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        print_error "Backup verification failed. Missing files: ${missing_files[*]}"
        return 1
    fi
    
    print_success "✓ Backup integrity verified"
    return 0
}

# Function to clean up old backups
cleanup_old_backups() {
    local env="$1"
    local keep_count=5
    
    print_status "Cleaning up old backups for $env environment..."
    
    local backup_dir="$PROJECT_ROOT/backups"
    
    # Find old backups for this environment
    local old_backups=($(ls -t "$backup_dir"/*_${env}_backup 2>/dev/null | tail -n +$((keep_count + 1)) || true))
    
    if [[ ${#old_backups[@]} -gt 0 ]]; then
        print_status "Removing ${#old_backups[@]} old backups..."
        for backup in "${old_backups[@]}"; do
            rm -rf "$backup"
            print_status "✓ Removed: $(basename "$backup")"
        done
        print_success "✓ Cleanup completed"
    else
        print_status "No old backups to clean up"
    fi
}

# Function to list existing backups
list_existing_backups() {
    local env="$1"
    
    print_status "Existing backups for $env environment:"
    
    local backup_dir="$PROJECT_ROOT/backups"
    
    if [[ -d "$backup_dir" ]]; then
        local backups=($(ls -t "$backup_dir"/*_${env}_backup 2>/dev/null || true))
        
        if [[ ${#backups[@]} -gt 0 ]]; then
            for backup in "${backups[@]}"; do
                local backup_name=$(basename "$backup")
                local backup_date=$(echo "$backup_name" | cut -d'_' -f1,2)
                echo "  - $backup_name (created: $backup_date)"
            done
        else
            print_status "No existing backups found"
        fi
    else
        print_status "No backup directory found"
    fi
}

# Function to backup single environment
backup_single_environment() {
    local env="$1"
    local cleanup="$2"
    
    print_status "Starting backup for $env environment..."
    echo "=================================================="
    
    # Check if environment exists
    if ! check_environment_exists "$env"; then
        print_error "Environment $env does not exist"
        return 1
    fi
    
    # Create backup directory
    local backup_dir=$(create_backup_directory "$env")
    print_status "Backup directory: $backup_dir"
    
    # Backup state files
    backup_state_files "$env" "$backup_dir"
    
    # Backup configuration files
    backup_config_files "$env" "$backup_dir"
    
    # Create backup metadata
    create_backup_metadata "$env" "$backup_dir"
    
    # Verify backup integrity
    if verify_backup_integrity "$backup_dir"; then
        print_success "✓ Backup completed successfully for $env environment"
        
        # Clean up old backups if requested
        if [[ "$cleanup" == "true" ]]; then
            cleanup_old_backups "$env"
        fi
        
        # List existing backups
        list_existing_backups "$env"
        
        echo "=================================================="
        return 0
    else
        print_error "✗ Backup verification failed for $env environment"
        echo "=================================================="
        return 1
    fi
}

# Function to backup all environments
backup_all_environments() {
    local cleanup="$1"
    local all_successful=true
    
    print_status "Backing up all environments..."
    
    for env in "${ENVIRONMENTS[@]}"; do
        if ! backup_single_environment "$env" "$cleanup"; then
            all_successful=false
        fi
        echo
    done
    
    if [[ "$all_successful" == "true" ]]; then
        print_success "All environment backups completed successfully!"
        return 0
    else
        print_error "Some environment backups failed"
        return 1
    fi
}

# Main execution
main() {
    local environment=""
    local cleanup=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            dev|staging|prod)
                environment="$1"
                shift
                ;;
            all)
                environment="all"
                shift
                ;;
            --cleanup)
                cleanup=true
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
    
    # Validate environment (if not "all")
    if [[ "$environment" != "all" ]]; then
        validate_environment "$environment"
    fi
    
    # Create backups directory if it doesn't exist
    mkdir -p "$PROJECT_ROOT/backups"
    
    # Run backup
    if [[ "$environment" == "all" ]]; then
        backup_all_environments "$cleanup"
    else
        backup_single_environment "$environment" "$cleanup"
    fi
}

# Run main function with all arguments
main "$@" 