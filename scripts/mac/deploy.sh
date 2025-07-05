#!/bin/bash

# Terraform Deployment Script (macOS)
# Usage: ./scripts/mac/deploy.sh [dev|staging|prod] [--force] [--dry-run]

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

# Function to show spinner animation
show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Function to run terraform command with spinner
run_terraform_with_spinner() {
    local command="$1"
    local args="$2"
    local activity="$3"
    local success_msg="$4"
    local error_msg="$5"
    
    print_status "$activity..."
    printf "Executing: "
    
    # Run terraform command in background and capture output
    terraform $command $args -no-color > /tmp/terraform_output.log 2>&1 &
    local terraform_pid=$!
    
    # Show spinner while command runs
    show_spinner $terraform_pid
    
    # Wait for command to complete
    wait $terraform_pid
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        print_success "$success_msg"
        return 0
    else
        print_error "$error_msg"
        print_error "Command output:"
        cat /tmp/terraform_output.log
        rm -f /tmp/terraform_output.log
        return 1
    fi
}

# Function to run terraform plan with progress
run_terraform_plan() {
    local env="$1"
    local plan_file="$2"
    
    print_status "Generating deployment plan..."
    printf "Analyzing infrastructure changes: "
    
    # Run plan with minimal output
    terraform plan -var="environment=$env" -out="$plan_file" -no-color > /tmp/terraform_plan.log 2>&1 &
    local plan_pid=$!
    
    # Show spinner while plan runs
    show_spinner $plan_pid
    
    # Wait for plan to complete
    wait $plan_pid
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        print_success "Plan generated successfully"
        rm -f /tmp/terraform_plan.log
        return 0
    else
        print_error "Plan generation failed"
        print_error "Plan output:"
        cat /tmp/terraform_plan.log
        rm -f /tmp/terraform_plan.log
        return 1
    fi
}

# Function to run terraform apply with progress
run_terraform_apply() {
    local plan_file="$1"
    local phase="$2"
    
    print_status "Applying $phase changes..."
    printf "Applying infrastructure changes: "
    
    # Run apply with minimal output
    terraform apply -auto-approve "$plan_file" -no-color > /tmp/terraform_apply.log 2>&1 &
    local apply_pid=$!
    
    # Show spinner while apply runs
    show_spinner $apply_pid
    
    # Wait for apply to complete
    wait $apply_pid
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        print_success "$phase deployment completed successfully!"
        rm -f /tmp/terraform_apply.log
        return 0
    else
        print_error "$phase deployment failed!"
        print_error "Apply output:"
        cat /tmp/terraform_apply.log
        rm -f /tmp/terraform_apply.log
        return 1
    fi
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
        
        # Check if database exists and is ready
        if gcloud firestore databases describe "$database_id" --project="$project_id" --format="value(state)" 2>/dev/null | grep -q "READY"; then
            print_success "Firestore database is ready!"
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            print_status "Database not ready yet, waiting 30 seconds..."
            sleep 30
        fi
    done
    
    print_warning "Database may not be fully ready, but continuing with deployment..."
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
    
    # Check if terraform init is needed
    if [ ! -d ".terraform" ]; then
        print_error "Terraform not initialized. Run 'terraform init' before deployment."
        exit 1
    fi
    
    # Validate Terraform configuration
    if ! run_terraform_with_spinner "validate" "" "Validating Terraform Configuration" "Terraform configuration is valid" "Terraform validation failed"; then
        exit 1
    fi
    
    # Format Terraform code
    print_status "Formatting Terraform code..."
    terraform fmt -recursive > /dev/null 2>&1
    
    # Generate plan for Phase 1
    if ! run_terraform_plan "$env" "tfplan-phase1"; then
        exit 1
    fi
    
    if [ "$dry_run" = true ]; then
        print_success "Phase 1 dry run completed. Review the plan above."
        return 0
    fi
    
    # Confirm deployment (unless --force is used)
    if [ "$force" != true ]; then
        echo ""
        print_warning "You are about to deploy Phase 1 to the $env environment."
        print_warning "This will create independent resources (VPC, database, etc.)."
        
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
    if ! run_terraform_apply "tfplan-phase1" "Phase 1"; then
        exit 1
    fi
    
    # Clean up plan file
    if [ -f "tfplan-phase1" ]; then
        rm "tfplan-phase1"
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
    
    # Check if terraform init is needed
    if [ ! -d ".terraform" ]; then
        print_error "Terraform not initialized. Run 'terraform init' before deployment."
        exit 1
    fi
    
    # Validate Terraform configuration
    if ! run_terraform_with_spinner "validate" "" "Validating Terraform Configuration" "Terraform configuration is valid" "Terraform validation failed"; then
        exit 1
    fi
    
    # Format Terraform code
    print_status "Formatting Terraform code..."
    terraform fmt -recursive > /dev/null 2>&1
    
    # Generate plan for Phase 2
    if ! run_terraform_plan "$env" "tfplan-phase2"; then
        exit 1
    fi
    
    if [ "$dry_run" = true ]; then
        print_success "Phase 2 dry run completed. Review the plan above."
        return 0
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
    print_warning "Firestore indexes can take 15-45 minutes to create."
    if ! run_terraform_apply "tfplan-phase2" "Phase 2"; then
        exit 1
    fi
    
    # Clean up plan file
    if [ -f "tfplan-phase2" ]; then
        rm "tfplan-phase2"
    fi
}

# Main execution
if [ "$HELP" = true ]; then
    show_usage
    exit 0
fi

# Validate environment
if [ -z "$ENVIRONMENT" ]; then
    print_error "Environment is required"
    show_usage
    exit 1
fi

# Check if environment is valid
if [[ ! " ${ENVIRONMENTS[@]} " =~ " ${ENVIRONMENT} " ]]; then
    print_error "Invalid environment: $ENVIRONMENT"
    show_usage
    exit 1
fi

print_status "Starting deployment to $ENVIRONMENT environment..."

# Check dependencies
check_dependencies

# Check environment configuration
check_environment_enabled "$ENVIRONMENT"

# Run preflight checks
run_preflight_checks "$ENVIRONMENT"

# Backup current state
backup_state "$ENVIRONMENT"

# Determine which phases to deploy
if [ "$PHASE1" = true ] && [ "$PHASE2" = true ]; then
    print_error "Cannot specify both --phase1 and --phase2. Choose one or neither for full deployment."
    exit 1
fi

if [ "$PHASE1" = true ]; then
    # Deploy only Phase 1
    print_status "Deploying Phase 1 only..."
    deploy_phase1 "$ENVIRONMENT" "$FORCE" "$DRY_RUN"
    print_success "Phase 1 deployment to $ENVIRONMENT completed successfully!"
    exit 0
fi

if [ "$PHASE2" = true ]; then
    # Deploy only Phase 2
    print_status "Deploying Phase 2 only..."
    deploy_phase2 "$ENVIRONMENT" "$FORCE" "$DRY_RUN"
    print_success "Phase 2 deployment to $ENVIRONMENT completed successfully!"
    exit 0
fi

# Default: Deploy both phases
print_status "Deploying both phases (default behavior)..."
deploy_phase1 "$ENVIRONMENT" "$FORCE" "$DRY_RUN"

if [ "$DRY_RUN" = true ]; then
    print_status "Phase 1 dry run completed. To continue with Phase 2, run: $0 $ENVIRONMENT --phase2"
    exit 0
fi

# Wait a bit between phases
print_status "Waiting 30 seconds between phases..."
sleep 30

# Deploy Phase 2
deploy_phase2 "$ENVIRONMENT" "$FORCE" "$DRY_RUN"

print_success "Full deployment to $ENVIRONMENT completed successfully!" 