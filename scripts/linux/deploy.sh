#!/bin/bash

# Terraform Deployment Script (Linux)
# Usage: ./scripts/linux/deploy.sh [dev|staging|prod] [--force] [--dry-run]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
ENVIRONMENTS=("dev" "staging" "prod")

# Parse command line arguments
ENVIRONMENT=""
FORCE=false
DRY_RUN=false
HELP=false
PHASE1=false
PHASE2=false

while [[ $# -gt 0 ]]; do
    case $1 in
        dev|staging|prod)
            ENVIRONMENT="$1"
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            HELP=true
            shift
            ;;
        --phase1)
            PHASE1=true
            shift
            ;;
        --phase2)
            PHASE2=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Function to show usage
show_usage() {
    echo "Usage: $0 [ENVIRONMENT] [OPTIONS]"
    echo ""
    echo "ENVIRONMENTS:"
    echo "    dev       - Deploy to development environment"
    echo "    staging   - Deploy to staging environment"
    echo "    prod      - Deploy to production environment (requires approval)"
    echo ""
    echo "OPTIONS:"
    echo "    --force     - Skip confirmation prompts"
    echo "    --dry-run   - Show what would be deployed without making changes"
    echo "    --help      - Show this help message"
    echo "    --phase1    - Deploy only Phase 1 (independent resources)"
    echo "    --phase2    - Deploy only Phase 2 (dependent resources)"
    echo ""
    echo "DEPLOYMENT PHASES:"
    echo "    Phase 1: Independent resources (main-independent.tf) - Database, VPC, networking, etc."
    echo "    Phase 2: Dependent resources (main-dependent.tf) - Indexes, functions, API Gateway, etc."
    echo ""
    echo "EXAMPLES:"
    echo "    $0 dev                    # Full deployment to dev"
    echo "    $0 dev --phase1           # Deploy only Phase 1"
    echo "    $0 dev --phase2           # Deploy only Phase 2"
    echo "    $0 staging --dry-run      # Show staging deployment plan"
    echo "    $0 prod --force           # Deploy to prod (skips confirmation)"
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
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_error "Please install the missing tools and try again."
        exit 1
    fi
}

# Function to check if environment is enabled
check_environment_enabled() {
    local env="$1"
    
    if [ "$env" = "prod" ]; then
        print_warning "Production environment deployment - extra care required"
    fi
    
    # Validate that the environment exists in the config
    local env_config_file="$PROJECT_ROOT/environments/$env.json"
    if [ ! -f "$env_config_file" ]; then
        print_error "Environment configuration file not found: $env_config_file"
        exit 1
    fi
}

# Function to run preflight checks
run_preflight_checks() {
    local env="$1"
    print_status "Running preflight checks for $env environment..."
    
    local preflight_script="$SCRIPT_DIR/preflight.sh"
    if [ -f "$preflight_script" ]; then
        "$preflight_script" "$env"
    else
        print_warning "Preflight script not found, skipping checks"
    fi
}

# Function to backup current state
backup_state() {
    local env="$1"
    print_status "Creating state backup for $env environment..."
    
    local backup_script="$SCRIPT_DIR/backup-state.sh"
    if [ -f "$backup_script" ]; then
        "$backup_script" "$env"
    else
        print_warning "Backup script not found, skipping state backup"
    fi
}

# Function to load environment configuration
load_environment_config() {
    local env="$1"
    local env_config_file="$PROJECT_ROOT/environments/$env.json"
    
    if [ ! -f "$env_config_file" ]; then
        print_error "Environment configuration file not found: $env_config_file"
        exit 1
    fi
    
    # Use jq if available, otherwise use basic parsing
    if command -v jq &> /dev/null; then
        jq -r '.' "$env_config_file"
    else
        cat "$env_config_file"
    fi
}

# Function to wait for Firestore database to be ready
wait_for_firestore_database() {
    local env="$1"
    
    print_status "Waiting for Firestore database to be ready..."
    local env_config_file="$PROJECT_ROOT/environments/$env.json"
    local project_id=$(jq -r '.project_id' "$env_config_file" 2>/dev/null || echo "")
    local database_id=$(jq -r '.firestore.database_id' "$env_config_file" 2>/dev/null || echo "db-dev")
    
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        attempt=$((attempt + 1))
        print_status "Checking database status (attempt $attempt/$max_attempts)..."
        
        if gcloud firestore databases describe "$database_id" --project="$project_id" >/dev/null 2>&1; then
            print_success "Firestore database is ready!"
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            print_status "Database not ready yet, waiting 10 seconds..."
            sleep 10
        fi
    done
    
    print_warning "Database may not be fully ready, but proceeding with deployment..."
    return 0
}

# Helper function to run terraform and handle backend reinit error
run_terraform_with_backend_check() {
    local terraform_args=("$@")
    
    local output
    if output=$(terraform "${terraform_args[@]}" 2>&1); then
        echo "$output"
    else
        echo "$output"
    fi
    
    # Check if backend reinitialization is required
    if echo "$output" | grep -q 'Backend initialization required, please run "terraform init"'; then
        print_warning "Backend reinitialization required. Running 'terraform init -reconfigure'..."
        terraform init -reconfigure
        
        # Retry the original command
        if output=$(terraform "${terraform_args[@]}" 2>&1); then
            echo "$output"
        else
            echo "$output"
        fi
    fi
    
    # Check for other common errors
    if echo "$output" | grep -q 'Error:'; then
        print_error "Terraform command failed. Check the output above for details."
        return 1
    fi
    
    return 0
}

# Function to deploy Phase 1 (independent resources)
deploy_phase1() {
    local env="$1"
    local force="$2"
    local dry_run="$3"
    
    print_status "Deploying Phase 1: Independent resources..."
    
    # Change to project root
    cd "$PROJECT_ROOT"
    
    # Get environment configuration for backend setup
    local env_config_file="$PROJECT_ROOT/environments/$env.json"
    local bucket_name=$(jq -r '.bucket_name' "$env_config_file")
    
    # Clean up any existing .terraform directory to ensure clean initialization
    if [ -d ".terraform" ]; then
        print_status "Removing existing .terraform directory for clean initialization..."
        rm -rf .terraform
    fi
    
    # Initialize Terraform with backend configuration
    print_status "Initializing Terraform with backend configuration..."
    terraform init \
        -backend-config="bucket=$bucket_name" \
        -backend-config="prefix=terraform/state"
    
    # Validate Terraform configuration
    print_status "Validating Terraform configuration..."
    if ! terraform validate; then
        print_error "Terraform validation failed"
        exit 1
    fi
    
    # Format Terraform code
    print_status "Formatting Terraform code..."
    terraform fmt -recursive
    
    # Show plan for Phase 1
    print_status "Generating Phase 1 deployment plan..."
    run_terraform_with_backend_check plan -var="environment=$env" -out=tfplan-phase1
    
    if [ "$dry_run" = true ]; then
        print_success "Phase 1 dry run completed. Review the plan above."
        print_status "To apply Phase 1, run: $0 $env --phase1"
        return
    fi
    
    # Confirm deployment (unless --force is used)
    if [ "$force" != true ]; then
        echo ""
        print_warning "You are about to deploy Phase 1 to the $env environment."
        print_warning "This will create the Firestore database and core infrastructure."
        
        if [ "$env" = "prod" ]; then
            print_warning "⚠️  PRODUCTION DEPLOYMENT - This affects live systems!"
            echo ""
            read -p "Type 'PRODUCTION' to confirm: " confirmation
            if [ "$confirmation" != "PRODUCTION" ]; then
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
    
    # Apply Phase 1 changes
    print_status "Applying Phase 1 changes..."
    run_terraform_with_backend_check apply -auto-approve tfplan-phase1
    
    if [ $? -eq 0 ]; then
        print_success "Phase 1 deployment completed successfully!"
        
        # Wait for database to be ready
        wait_for_firestore_database "$env"
        
        # Show outputs
        print_status "Phase 1 outputs:"
        terraform output
    else
        print_error "Phase 1 deployment failed!"
        exit 1
    fi
    
    # Clean up plan file
    if [ -f "tfplan-phase1" ]; then
        rm tfplan-phase1
    fi
}

# Function to deploy Phase 2 (dependent resources)
deploy_phase2() {
    local env="$1"
    local force="$2"
    local dry_run="$3"
    
    print_status "Deploying Phase 2: Dependent resources..."
    
    # Change to project root
    cd "$PROJECT_ROOT"
    
    # Get environment configuration for backend setup
    local env_config_file="$PROJECT_ROOT/environments/$env.json"
    local bucket_name=$(jq -r '.bucket_name' "$env_config_file")
    
    # Clean up any existing .terraform directory to ensure clean initialization
    if [ -d ".terraform" ]; then
        print_status "Removing existing .terraform directory for clean initialization..."
        rm -rf .terraform
    fi
    
    # Initialize Terraform with backend configuration
    print_status "Initializing Terraform with backend configuration..."
    terraform init \
        -backend-config="bucket=$bucket_name" \
        -backend-config="prefix=terraform/state"
    
    # Validate Terraform configuration
    print_status "Validating Terraform configuration..."
    if ! terraform validate; then
        print_error "Terraform validation failed"
        exit 1
    fi
    
    # Format Terraform code
    print_status "Formatting Terraform code..."
    terraform fmt -recursive
    
    # Show plan for Phase 2
    print_status "Generating Phase 2 deployment plan..."
    run_terraform_with_backend_check plan -var="environment=$env" -out=tfplan-phase2
    
    if [ "$dry_run" = true ]; then
        print_success "Phase 2 dry run completed. Review the plan above."
        print_status "To apply Phase 2, run: $0 $env --phase2"
        return
    fi
    
    # Confirm deployment (unless --force is used)
    if [ "$force" != true ]; then
        echo ""
        print_warning "You are about to deploy Phase 2 to the $env environment."
        print_warning "This will create Firestore indexes and dependent resources."
        print_warning "Firestore indexes can take 15-45 minutes to create."
        
        if [ "$env" = "prod" ]; then
            print_warning "⚠️  PRODUCTION DEPLOYMENT - This affects live systems!"
            echo ""
            read -p "Type 'PRODUCTION' to confirm: " confirmation
            if [ "$confirmation" != "PRODUCTION" ]; then
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
    
    # Apply Phase 2 changes
    print_status "Applying Phase 2 changes..."
    print_warning "Firestore indexes can take 15-45 minutes to create."
    print_status "Starting Phase 2 apply process..."
    run_terraform_with_backend_check apply -auto-approve tfplan-phase2
    
    if [ $? -eq 0 ]; then
        print_success "Phase 2 deployment completed successfully!"
        
        # Show outputs
        print_status "Phase 2 outputs:"
        terraform output
    else
        print_error "Phase 2 deployment failed!"
        print_status "Check the error messages above and fix any issues."
        print_status "You can run 'python scripts/run rollback $env' if needed."
        exit 1
    fi
    
    # Clean up plan file
    if [ -f "tfplan-phase2" ]; then
        rm tfplan-phase2
    fi
}

# Function to deploy to environment (full deployment)
deploy_environment() {
    local env="$1"
    local force="$2"
    local dry_run="$3"
    
    print_status "Deploying to $env environment (full deployment)..."
    
    # Deploy Phase 1 first
    deploy_phase1 "$env" "$force" "$dry_run"
    
    if [ "$dry_run" = true ]; then
        print_status "Phase 1 dry run completed. To continue with Phase 2, run: $0 $env --phase2"
        return
    fi
    
    # Wait a bit between phases
    print_status "Waiting 30 seconds between phases..."
    sleep 30
    
    # Deploy Phase 2
    deploy_phase2 "$env" "$force" "$dry_run"
    
    print_success "Full deployment to $env completed successfully!"
}

# Function to check active gcloud project matches environment
check_gcloud_project() {
    local env="$1"
    local env_config_file="$PROJECT_ROOT/environments/$env.json"
    local expected_project=$(jq -r '.project_id' "$env_config_file")
    local active_project=$(gcloud config get-value project 2>/dev/null | tr -d ' ')
    
    if [ "$active_project" != "$expected_project" ]; then
        print_error "Active gcloud project ($active_project) does not match environment project_id ($expected_project)."
        print_error "Run: gcloud config set project $expected_project"
        exit 1
    fi
}

# Main execution
if [ "$HELP" = true ]; then
    show_usage
    exit 0
fi

# Validate environment parameter
if [ -z "$ENVIRONMENT" ]; then
    print_error "Environment parameter is required"
    show_usage
    exit 1
fi

# Check if environment is valid
if [[ ! " ${ENVIRONMENTS[@]} " =~ " ${ENVIRONMENT} " ]]; then
    print_error "Invalid environment: $ENVIRONMENT"
    print_error "Valid environments: ${ENVIRONMENTS[*]}"
    exit 1
fi

# Check dependencies
check_dependencies

# Check if environment is enabled
check_environment_enabled "$ENVIRONMENT"

# Check gcloud project matches environment
check_gcloud_project "$ENVIRONMENT"

# Run preflight checks
run_preflight_checks "$ENVIRONMENT"

# Backup current state
backup_state "$ENVIRONMENT"

# Determine deployment type
if [ "$PHASE1" = true ]; then
    deploy_phase1 "$ENVIRONMENT" "$FORCE" "$DRY_RUN"
elif [ "$PHASE2" = true ]; then
    deploy_phase2 "$ENVIRONMENT" "$FORCE" "$DRY_RUN"
else
    deploy_environment "$ENVIRONMENT" "$FORCE" "$DRY_RUN"
fi 