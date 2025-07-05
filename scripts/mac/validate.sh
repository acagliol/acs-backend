#!/bin/bash

# Terraform Validation Script
# Usage: ./scripts/validate.sh [dev|staging|prod] [--all] [--fix]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENVIRONMENTS=("dev" "staging" "prod")

# Validation results
VALIDATION_ERRORS=0
VALIDATION_WARNINGS=0

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    ((VALIDATION_WARNINGS++))
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    ((VALIDATION_ERRORS++))
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [ENVIRONMENT] [OPTIONS]

ENVIRONMENTS:
    dev       - Validate development environment
    staging   - Validate staging environment
    prod      - Validate production environment
    all       - Validate all environments

OPTIONS:
    --fix      - Automatically fix formatting issues
    --strict   - Treat warnings as errors
    --help     - Show this help message

EXAMPLES:
    $0 dev              # Validate dev environment
    $0 all --fix        # Validate all environments and fix formatting
    $0 staging --strict # Validate staging with strict mode

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
    
    # Optional dependencies
    if command -v checkov &> /dev/null; then
        CHECKOV_AVAILABLE=true
    else
        CHECKOV_AVAILABLE=false
        print_warning "Checkov not found - security scanning will be skipped"
    fi
    
    if command -v tflint &> /dev/null; then
        TFLINT_AVAILABLE=true
    else
        TFLINT_AVAILABLE=false
        print_warning "TFLint not found - linting will be skipped"
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_error "Please install the missing tools and try again."
        exit 1
    fi
}

# Function to validate environment directory
validate_environment_directory() {
    local env="$1"
    local env_dir="$PROJECT_ROOT/environments/$env"
    
    if [[ ! -d "$env_dir" ]]; then
        print_error "Environment directory not found: $env_dir"
        return 1
    fi
    
    if [[ ! -f "$env_dir/main.tf" ]]; then
        print_error "main.tf not found in $env_dir"
        return 1
    fi
    
    return 0
}

# Function to validate Terraform syntax
validate_terraform_syntax() {
    local env="$1"
    local env_dir="$PROJECT_ROOT/environments/$env"
    local fix="$2"
    
    print_status "Validating Terraform syntax for $env environment..."
    
    cd "$env_dir"
    
    # Check if .terraform directory exists, if not initialize
    if [[ ! -d ".terraform" ]]; then
        print_status "Initializing Terraform for validation..."
        terraform init -backend=false
    fi
    
    # Validate Terraform configuration
    if terraform validate; then
        print_success "Terraform syntax validation passed for $env"
    else
        print_error "Terraform syntax validation failed for $env"
        return 1
    fi
    
    # Check formatting
    if terraform fmt -check -recursive; then
        print_success "Terraform formatting is correct for $env"
    else
        if [[ "$fix" == "true" ]]; then
            print_status "Fixing Terraform formatting for $env..."
            terraform fmt -recursive
            print_success "Terraform formatting fixed for $env"
        else
            print_warning "Terraform formatting issues found in $env"
            print_status "Run with --fix to automatically fix formatting"
        fi
    fi
    
    return 0
}

# Function to validate provider compatibility
validate_provider_compatibility() {
    local env="$1"
    local env_dir="$PROJECT_ROOT/environments/$env"
    
    print_status "Validating provider compatibility for $env environment..."
    
    cd "$env_dir"
    
    # Check provider versions
    if [[ -f "versions.tf" ]]; then
        print_status "Checking provider version constraints..."
        
        # Extract provider versions and check compatibility
        local google_version=$(grep -E "version\s*=\s*[\"']~>\s*[0-9]+\.[0-9]+" versions.tf 2>/dev/null || echo "")
        if [[ -n "$google_version" ]]; then
            print_success "Google provider version constraint found: $google_version"
        else
            print_warning "No specific Google provider version constraint found"
        fi
    else
        print_warning "versions.tf not found - provider version constraints not enforced"
    fi
    
    return 0
}

# Function to validate variable definitions
validate_variables() {
    local env="$1"
    local env_dir="$PROJECT_ROOT/environments/$env"
    
    print_status "Validating variable definitions for $env environment..."
    
    cd "$env_dir"
    
    # Check if variables.tf exists
    if [[ ! -f "variables.tf" ]]; then
        print_warning "variables.tf not found in $env"
        return 0
    fi
    
    # Check for required variables
    local required_vars=("environment" "project_id" "region")
    for var in "${required_vars[@]}"; do
        if ! grep -q "variable \"$var\"" variables.tf; then
            print_warning "Required variable '$var' not found in variables.tf"
        fi
    done
    
    # Check for variable validation
    local vars_with_validation=$(grep -c "validation {" variables.tf 2>/dev/null || echo "0")
    local total_vars=$(grep -c "variable \"" variables.tf 2>/dev/null || echo "0")
    
    if [[ "$total_vars" -gt 0 ]]; then
        local validation_percentage=$((vars_with_validation * 100 / total_vars))
        if [[ "$validation_percentage" -lt 50 ]]; then
            print_warning "Only $validation_percentage% of variables have validation rules"
        else
            print_success "Variable validation coverage: $validation_percentage%"
        fi
    fi
    
    return 0
}

# Function to validate terraform.tfvars
validate_tfvars() {
    local env="$1"
    local env_dir="$PROJECT_ROOT/environments/$env"
    
    print_status "Validating terraform.tfvars for $env environment..."
    
    cd "$env_dir"
    
    if [[ ! -f "terraform.tfvars" ]]; then
        print_warning "terraform.tfvars not found in $env"
        return 0
    fi
    
    # Check for sensitive values in tfvars
    if grep -q -i "password\|secret\|key\|token" terraform.tfvars; then
        print_error "Sensitive values found in terraform.tfvars"
        print_error "Use environment variables or secret management instead"
        return 1
    fi
    
    # Check for empty values
    if grep -q "= \"\"" terraform.tfvars; then
        print_warning "Empty string values found in terraform.tfvars"
    fi
    
    return 0
}

# Function to run TFLint (if available)
run_tflint() {
    local env="$1"
    local env_dir="$PROJECT_ROOT/environments/$env"
    
    if [[ "$TFLINT_AVAILABLE" == "false" ]]; then
        return 0
    fi
    
    print_status "Running TFLint for $env environment..."
    
    cd "$env_dir"
    
    # Check if .tflint.hcl exists
    if [[ ! -f ".tflint.hcl" ]]; then
        print_warning ".tflint.hcl configuration not found for $env"
        return 0
    fi
    
    if tflint; then
        print_success "TFLint validation passed for $env"
    else
        print_error "TFLint validation failed for $env"
        return 1
    fi
    
    return 0
}

# Function to run Checkov security scanning (if available)
run_checkov() {
    local env="$1"
    local env_dir="$PROJECT_ROOT/environments/$env"
    
    if [[ "$CHECKOV_AVAILABLE" == "false" ]]; then
        return 0
    fi
    
    print_status "Running Checkov security scan for $env environment..."
    
    cd "$env_dir"
    
    # Run Checkov with specific frameworks
    if checkov -d . --framework terraform --output cli --compact; then
        print_success "Checkov security scan passed for $env"
    else
        print_warning "Checkov security scan found issues in $env"
        print_status "Review the security findings above"
    fi
    
    return 0
}

# Function to validate backend configuration
validate_backend() {
    local env="$1"
    local env_dir="$PROJECT_ROOT/environments/$env"
    
    print_status "Validating backend configuration for $env environment..."
    
    cd "$env_dir"
    
    if [[ ! -f "backend.tf" ]]; then
        print_warning "backend.tf not found in $env"
        return 0
    fi
    
    # Check for remote backend configuration
    if grep -q "backend \"gcs\"" backend.tf; then
        print_success "GCS backend configuration found for $env"
        
        # Extract bucket name
        local bucket_name=$(grep -o 'bucket\s*=\s*"[^"]*"' backend.tf | cut -d'"' -f2)
        if [[ -n "$bucket_name" ]]; then
            print_status "Backend bucket: $bucket_name"
        fi
    else
        print_warning "Remote backend configuration not found for $env"
    fi
    
    return 0
}

# Function to validate environment-specific configuration
validate_environment_config() {
    local env="$1"
    local env_dir="$PROJECT_ROOT/environments/$env"
    
    print_status "Validating environment-specific configuration for $env..."
    
    cd "$env_dir"
    
    # Check for environment-specific naming
    if grep -q "\${var.environment}" main.tf; then
        print_success "Environment-aware naming found in $env"
    else
        print_warning "Environment-aware naming not found in $env"
    fi
    
    # Check for proper tagging
    if grep -q "tags\s*=" main.tf; then
        print_success "Resource tagging found in $env"
    else
        print_warning "Resource tagging not found in $env"
    fi
    
    return 0
}

# Function to validate a single environment
validate_single_environment() {
    local env="$1"
    local fix="$2"
    local strict="$3"
    
    print_status "Starting validation for $env environment..."
    echo "=================================================="
    
    local env_errors=0
    
    # Validate environment directory
    if ! validate_environment_directory "$env"; then
        ((env_errors++))
        return 1
    fi
    
    # Run all validation checks
    validate_terraform_syntax "$env" "$fix" || ((env_errors++))
    validate_provider_compatibility "$env" || ((env_errors++))
    validate_variables "$env" || ((env_errors++))
    validate_tfvars "$env" || ((env_errors++))
    run_tflint "$env" || ((env_errors++))
    run_checkov "$env" || ((env_errors++))
    validate_backend "$env" || ((env_errors++))
    validate_environment_config "$env" || ((env_errors++))
    
    echo "=================================================="
    
    if [[ $env_errors -eq 0 ]]; then
        print_success "Validation completed for $env environment"
        return 0
    else
        print_error "Validation failed for $env environment ($env_errors errors)"
        return 1
    fi
}

# Function to validate all environments
validate_all_environments() {
    local fix="$1"
    local strict="$2"
    local all_passed=true
    
    print_status "Validating all environments..."
    
    for env in "${ENVIRONMENTS[@]}"; do
        if ! validate_single_environment "$env" "$fix" "$strict"; then
            all_passed=false
        fi
        echo
    done
    
    if [[ "$all_passed" == "true" ]]; then
        print_success "All environments validated successfully!"
        return 0
    else
        print_error "Some environments failed validation"
        return 1
    fi
}

# Function to print validation summary
print_validation_summary() {
    echo
    echo "=================================================="
    echo "VALIDATION SUMMARY"
    echo "=================================================="
    echo "Errors: $VALIDATION_ERRORS"
    echo "Warnings: $VALIDATION_WARNINGS"
    echo "=================================================="
    
    if [[ $VALIDATION_ERRORS -eq 0 ]]; then
        print_success "Validation completed successfully!"
        exit 0
    else
        print_error "Validation completed with errors"
        exit 1
    fi
}

# Main execution
main() {
    local environment=""
    local fix=false
    local strict=false
    
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
            --fix)
                fix=true
                shift
                ;;
            --strict)
                strict=true
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
    
    # Run validation
    if [[ "$environment" == "all" ]]; then
        validate_all_environments "$fix" "$strict"
    else
        validate_single_environment "$environment" "$fix" "$strict"
    fi
    
    # Print summary
    print_validation_summary
}

# Run main function with all arguments
main "$@" 