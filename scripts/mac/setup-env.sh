#!/bin/bash

# Environment Setup Script
# Usage: ./scripts/setup-env.sh [dev|staging|prod]

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

# Function to load environment configuration
load_environment_config() {
    local env="$1"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    # Use jq to parse JSON if available, otherwise use a simple grep approach
    if command -v jq &> /dev/null; then
        local config
        config=$(jq -r ".environments.$env" "$CONFIG_FILE" 2>/dev/null)
        if [[ "$config" == "null" ]] || [[ -z "$config" ]]; then
            print_error "Environment '$env' not found in configuration file"
            exit 1
        fi
        echo "$config"
    else
        print_warning "jq not found, using fallback configuration parsing"
        # Fallback: extract values using grep/sed (less robust)
        case "$env" in
            dev)
                echo '{"project_id":"terraform-anay-dev","bucket_name":"terraform-state-dev-anay","region":"us-central1","zone":"us-central1-c","machine_type":"e2-micro","subnet_cidr":"10.0.1.0/24","disk_size":20}'
                ;;
            staging)
                echo '{"project_id":"terraform-anay-staging","bucket_name":"terraform-state-staging-anay","region":"us-central1","zone":"us-central1-c","machine_type":"e2-small","subnet_cidr":"10.0.2.0/24","disk_size":20}'
                ;;
            prod)
                echo '{"project_id":"terraform-anay-prod","bucket_name":"terraform-state-prod-anay","region":"us-central1","zone":"us-central1-c","machine_type":"e2-standard-2","subnet_cidr":"10.0.3.0/24","disk_size":50}'
                ;;
            *)
                print_error "Environment '$env' not found in configuration file"
                exit 1
                ;;
        esac
    fi
}

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
    dev       - Set up development environment
    staging   - Set up staging environment
    prod      - Set up production environment (admin only)

OPTIONS:
    --force     - Overwrite existing environment
    --template  - Use template configuration
    --help      - Show this help message

EXAMPLES:
    $0 dev              # Set up dev environment
    $0 staging --force  # Set up staging environment (overwrite existing)
    $0 prod --template  # Set up prod environment with template

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

# Function to check permissions for production
check_production_permissions() {
    local env="$1"
    
    if [[ "$env" == "prod" ]]; then
        print_warning "Setting up production environment requires admin permissions"
        print_status "Please ensure you have the necessary access rights"
        
        read -p "Do you have admin permissions for production? (y/N): " confirmation
        if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
            print_error "Production setup cancelled - admin permissions required"
            exit 1
        fi
    fi
}

# Function to create environment directory
create_environment_directory() {
    local env="$1"
    local env_dir="$PROJECT_ROOT/environments/$env"
    
    print_status "Creating environment directory: $env_dir"
    
    if [[ -d "$env_dir" ]]; then
        print_warning "Environment directory already exists: $env_dir"
        return 1
    fi
    
    mkdir -p "$env_dir"
    print_success "Environment directory created"
}

# Function to create main.tf
create_main_tf() {
    local env="$1"
    local env_dir="$2"
    
    print_status "Creating main.tf for $env environment..."
    
    cat > "$env_dir/main.tf" << EOF
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# VPC Network
resource "google_compute_network" "vpc_network" {
  name                    = "vpc-network-\${var.environment}"
  auto_create_subnetworks = false
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "subnet-\${var.environment}"
  ip_cidr_range = var.subnet_cidr
  network       = google_compute_network.vpc_network.id
  region        = var.region
}

# Firewall rule for internal communication
resource "google_compute_firewall" "internal" {
  name    = "allow-internal-\${var.environment}"
  network = google_compute_network.vpc_network.name
  
  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  
  allow {
    protocol = "icmp"
  }
  
  source_ranges = [var.subnet_cidr]
}

# Compute instance
resource "google_compute_instance" "vm_instance" {
  name         = "vm-instance-\${var.environment}"
  machine_type = var.machine_type
  zone         = var.zone
  
  tags = ["web", var.environment]

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
      size  = var.disk_size
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id
    access_config {
      // Ephemeral public IP
    }
  }

  metadata = {
    environment = var.environment
    managed_by  = "terraform"
  }

  labels = {
    environment = var.environment
    project     = var.project_id
    managed_by  = "terraform"
  }
}

# Outputs
output "instance_external_ip" {
  description = "External IP address of the compute instance"
  value       = google_compute_instance.vm_instance.network_interface[0].access_config[0].nat_ip
}

output "instance_internal_ip" {
  description = "Internal IP address of the compute instance"
  value       = google_compute_instance.vm_instance.network_interface[0].network_ip
}

output "vpc_network_name" {
  description = "Name of the VPC network"
  value       = google_compute_network.vpc_network.name
}

output "subnet_name" {
  description = "Name of the subnet"
  value       = google_compute_subnetwork.subnet.name
}
EOF
    
    print_success "main.tf created"
}

# Function to create variables.tf
create_variables_tf() {
    local env="$1"
    local env_dir="$2"
    
    print_status "Creating variables.tf for $env environment..."
    
    cat > "$env_dir/variables.tf" << EOF
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
  
  validation {
    condition     = length(var.project_id) > 0
    error_message = "Project ID cannot be empty."
  }
}

variable "region" {
  description = "Google Cloud region"
  type        = string
  default     = "us-central1"
  
  validation {
    condition     = length(var.region) > 0
    error_message = "Region cannot be empty."
  }
}

variable "zone" {
  description = "Google Cloud zone"
  type        = string
  default     = "us-central1-c"
  
  validation {
    condition     = length(var.zone) > 0
    error_message = "Zone cannot be empty."
  }
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
  default     = "10.0.1.0/24"
  
  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0))
    error_message = "Subnet CIDR must be a valid CIDR block."
  }
}

variable "machine_type" {
  description = "Machine type for the compute instance"
  type        = string
  
  validation {
    condition     = length(var.machine_type) > 0
    error_message = "Machine type cannot be empty."
  }
}

variable "disk_size" {
  description = "Size of the boot disk in GB"
  type        = number
  default     = 20
  
  validation {
    condition     = var.disk_size >= 10 && var.disk_size <= 2000
    error_message = "Disk size must be between 10 and 2000 GB."
  }
}
EOF
    
    print_success "variables.tf created"
}

# Function to create terraform.tfvars
create_tfvars() {
    local env="$1"
    local env_dir="$2"
    
    print_status "Creating terraform.tfvars for $env environment..."
    
    # Load environment configuration
    local env_config
    env_config=$(load_environment_config "$env")
    
    # Extract values from JSON (using jq if available, otherwise use fallback)
    local project_id
    local region
    local zone
    local machine_type
    local subnet_cidr
    local disk_size
    
    if command -v jq &> /dev/null; then
        project_id=$(echo "$env_config" | jq -r '.project_id')
        region=$(echo "$env_config" | jq -r '.region')
        zone=$(echo "$env_config" | jq -r '.zone')
        machine_type=$(echo "$env_config" | jq -r '.machine_type')
        subnet_cidr=$(echo "$env_config" | jq -r '.subnet_cidr')
        disk_size=$(echo "$env_config" | jq -r '.disk_size')
    else
        # Fallback parsing (less robust)
        case "$env" in
            dev)
                project_id="terraform-anay-dev"
                region="us-central1"
                zone="us-central1-c"
                machine_type="e2-micro"
                subnet_cidr="10.0.1.0/24"
                disk_size=20
                ;;
            staging)
                project_id="terraform-anay-staging"
                region="us-central1"
                zone="us-central1-c"
                machine_type="e2-small"
                subnet_cidr="10.0.2.0/24"
                disk_size=20
                ;;
            prod)
                project_id="terraform-anay-prod"
                region="us-central1"
                zone="us-central1-c"
                machine_type="e2-standard-2"
                subnet_cidr="10.0.3.0/24"
                disk_size=50
                ;;
        esac
    fi
    
    cat > "$env_dir/terraform.tfvars" << EOF
# Environment Configuration
environment = "$env"
project_id  = "$project_id"
region      = "$region"
zone        = "$zone"

# Network Configuration
subnet_cidr = "$subnet_cidr"

# Compute Configuration
machine_type = "$machine_type"
disk_size    = $disk_size
EOF
    
    print_success "terraform.tfvars created"
}

# Function to create backend.tf
create_backend_tf() {
    local env="$1"
    local env_dir="$2"
    
    print_status "Creating backend.tf for $env environment..."
    
    # Load environment configuration
    local env_config
    env_config=$(load_environment_config "$env")
    
    # Extract values from JSON
    local bucket_name
    if command -v jq &> /dev/null; then
        bucket_name=$(echo "$env_config" | jq -r '.bucket_name')
    else
        # Fallback parsing
        case "$env" in
            dev)
                bucket_name="terraform-state-dev-anay"
                ;;
            staging)
                bucket_name="terraform-state-staging-anay"
                ;;
            prod)
                bucket_name="terraform-state-prod-anay"
                ;;
        esac
    fi
    
    cat > "$env_dir/backend.tf" << EOF
terraform {
  backend "gcs" {
    bucket  = "$bucket_name"
    prefix  = "terraform/state"
  }
}
EOF
    
    print_success "backend.tf created"
}

# Function to create versions.tf
create_versions_tf() {
    local env="$1"
    local env_dir="$2"
    
    print_status "Creating versions.tf for $env environment..."
    
    cat > "$env_dir/versions.tf" << EOF
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}
EOF
    
    print_success "versions.tf created"
}

# Function to create .tflint.hcl
create_tflint_hcl() {
    local env="$1"
    local env_dir="$2"
    
    print_status "Creating .tflint.hcl for $env environment..."
    
    cat > "$env_dir/.tflint.hcl" << EOF
plugin "google" {
  enabled = true
  version = "0.27.0"
  source  = "github.com/terraform-linters/tflint-ruleset-google"
}

config {
  module = true
  force  = false
}

rule "google_compute_instance_invalid_machine_type" {
  enabled = true
}

rule "google_compute_disk_invalid_image" {
  enabled = true
}

rule "google_compute_firewall_invalid_source_ranges" {
  enabled = true
}
EOF
    
    print_success ".tflint.hcl created"
}

# Function to create README.md
create_readme() {
    local env="$1"
    local env_dir="$2"
    
    print_status "Creating README.md for $env environment..."
    
    cat > "$env_dir/README.md" << EOF
# $env Environment

This directory contains the Terraform configuration for the **$env** environment.

## Files

- \`main.tf\` - Main Terraform configuration
- \`variables.tf\` - Variable definitions
- \`terraform.tfvars\` - Environment-specific variable values
- \`backend.tf\` - Remote state configuration
- \`versions.tf\` - Provider and Terraform version constraints
- \`.tflint.hcl\` - TFLint configuration

## Usage

### Initialize
\`\`\`bash
terraform init
\`\`\`

### Plan
\`\`\`bash
terraform plan
\`\`\`

### Apply
\`\`\`bash
terraform apply
\`\`\`

### Destroy
\`\`\`bash
terraform destroy
\`\`\`

## Environment-Specific Configuration

This environment is configured for **$env** with the following characteristics:

- **Project ID**: terraform-$env-project
- **Region**: us-central1
- **Zone**: us-central1-c
- **Machine Type**: $(case "$env" in dev) echo "e2-micro" ;; staging) echo "e2-small" ;; prod) echo "e2-standard-2" ;; esac)

## Security Notes

- All resources are tagged with the environment name
- Network access is restricted to the subnet CIDR
- Resources follow naming conventions with environment prefixes

## Maintenance

- Run \`terraform fmt\` to format code
- Run \`terraform validate\` to check syntax
- Run \`tflint\` to check for best practices
- Keep provider versions updated

EOF
    
    print_success "README.md created"
}

# Function to initialize Terraform
initialize_terraform() {
    local env="$1"
    local env_dir="$2"
    
    print_status "Initializing Terraform for $env environment..."
    
    cd "$env_dir"
    
    # Initialize Terraform
    if terraform init; then
        print_success "Terraform initialized successfully"
    else
        print_error "Terraform initialization failed"
        return 1
    fi
    
    # Validate configuration
    if terraform validate; then
        print_success "Terraform configuration is valid"
    else
        print_error "Terraform configuration validation failed"
        return 1
    fi
    
    # Format code
    terraform fmt -recursive
    print_success "Terraform code formatted"
}

# Function to setup environment
setup_environment() {
    local env="$1"
    local force="$2"
    local env_dir="$PROJECT_ROOT/environments/$env"
    
    print_status "Setting up $env environment..."
    echo "=================================================="
    
    # Check if environment already exists
    if [[ -d "$env_dir" ]] && [[ "$force" != "true" ]]; then
        print_error "Environment $env already exists"
        print_status "Use --force to overwrite existing environment"
        return 1
    fi
    
    # Create environment directory
    if [[ -d "$env_dir" ]] && [[ "$force" == "true" ]]; then
        print_warning "Overwriting existing environment: $env"
        rm -rf "$env_dir"
    fi
    
    create_environment_directory "$env"
    
    # Create configuration files
    create_main_tf "$env" "$env_dir"
    create_variables_tf "$env" "$env_dir"
    create_tfvars "$env" "$env_dir"
    create_backend_tf "$env" "$env_dir"
    create_versions_tf "$env" "$env_dir"
    create_tflint_hcl "$env" "$env_dir"
    create_readme "$env" "$env_dir"
    
    # Initialize Terraform
    if initialize_terraform "$env" "$env_dir"; then
        echo "=================================================="
        print_success "$env environment setup completed successfully!"
        
        print_status "Next steps:"
        echo "1. Review the configuration in $env_dir/"
        echo "2. Update terraform.tfvars with your specific values"
        echo "3. Run: ./scripts/validate.sh $env"
        echo "4. Run: ./scripts/deploy.sh $env --dry-run"
        echo "5. Run: ./scripts/deploy.sh $env"
        
        return 0
    else
        echo "=================================================="
        print_error "$env environment setup failed"
        return 1
    fi
}

# Main execution
main() {
    local environment=""
    local force=false
    local template=false
    
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
            --template)
                template=true
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
    
    # Check production permissions
    check_production_permissions "$environment"
    
    # Setup environment
    setup_environment "$environment" "$force"
}

# Run main function with all arguments
main "$@" 