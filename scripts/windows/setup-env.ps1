# Environment Setup Script (PowerShell)
# Usage: .\scripts\windows\setup-env.ps1 [dev|staging|prod] [-Force] [-Help]

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,
    
    [switch]$Force,
    [switch]$Help
)

# Script configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$ConfigFile = Join-Path $ProjectRoot "config\environments.json"
$Environments = @("dev", "staging", "prod")

# Function to load environment configuration
function Get-EnvironmentConfig {
    param([string]$env)
    
    if (-not (Test-Path $ConfigFile)) {
        Write-Error "Configuration file not found: $ConfigFile"
        exit 1
    }
    
    try {
        $config = Get-Content $ConfigFile | ConvertFrom-Json
        if ($config.environments.$env) {
            return $config.environments.$env
        } else {
            Write-Error "Environment '$env' not found in configuration file"
            exit 1
        }
    } catch {
        Write-Error "Failed to load configuration file: $($_.Exception.Message)"
        exit 1
    }
}

# Function to print colored output
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Function to show usage
function Show-Usage {
    Write-Host @"
Usage: $($MyInvocation.MyCommand.Name) [ENVIRONMENT] [OPTIONS]

ENVIRONMENTS:
    dev       - Set up development environment
    staging   - Set up staging environment
    prod      - Set up production environment (admin only)

OPTIONS:
    -Force     - Overwrite existing environment
    -Help      - Show this help message

EXAMPLES:
    $($MyInvocation.MyCommand.Name) dev              # Set up dev environment
    $($MyInvocation.MyCommand.Name) staging -Force   # Set up staging environment (overwrite existing)
    $($MyInvocation.MyCommand.Name) prod             # Set up prod environment

"@
}

# Function to check dependencies
function Test-Dependencies {
    $missingDeps = @()
    
    if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
        $missingDeps += "terraform"
    }
    
    if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
        $missingDeps += "gcloud"
    }
    
    if ($missingDeps.Count -gt 0) {
        Write-Error "Missing required dependencies: $($missingDeps -join ', ')"
        Write-Error "Please install the missing tools and try again."
        exit 1
    }
}

# Function to check permissions for production
function Test-ProductionPermissions {
    param([string]$env)
    
    if ($env -eq "prod") {
        Write-Warning "Setting up production environment requires admin permissions"
        Write-Status "Please ensure you have the necessary access rights"
        
        $confirmation = Read-Host "Do you have admin permissions for production? (y/N)"
        if ($confirmation -notmatch "^[Yy]$") {
            Write-Error "Production setup cancelled - admin permissions required"
            exit 1
        }
    }
}

# Function to create environment directory
function New-EnvironmentDirectory {
    param([string]$env)
    $envDir = Join-Path $ProjectRoot "environments\$env"
    
    Write-Status "Creating environment directory: $envDir"
    
    if (Test-Path $envDir) {
        Write-Warning "Environment directory already exists: $envDir"
        return $false
    }
    
    New-Item -ItemType Directory -Path $envDir -Force | Out-Null
    Write-Success "Environment directory created"
    return $true
}

# Function to create main.tf
function New-MainTF {
    param(
        [string]$env,
        [string]$envDir
    )
    
    Write-Status "Creating main.tf for $env environment..."
    
    $mainContent = @"
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# VPC Network
resource "google_compute_network" "vpc_network" {
  name                    = "vpc-network-`${var.environment}"
  auto_create_subnetworks = false
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "subnet-`${var.environment}"
  ip_cidr_range = var.subnet_cidr
  network       = google_compute_network.vpc_network.id
  region        = var.region
}

# Firewall rule for internal communication
resource "google_compute_firewall" "internal" {
  name    = "allow-internal-`${var.environment}"
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
  name         = "vm-instance-`${var.environment}"
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
"@
    
    $mainContent | Out-File -FilePath (Join-Path $envDir "main.tf") -Encoding UTF8
    Write-Success "main.tf created"
}

# Function to create variables.tf
function New-VariablesTF {
    param(
        [string]$env,
        [string]$envDir
    )
    
    Write-Status "Creating variables.tf for $env environment..."
    
    $variablesContent = @"
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
"@
    
    $variablesContent | Out-File -FilePath (Join-Path $envDir "variables.tf") -Encoding UTF8
    Write-Success "variables.tf created"
}

# Function to create terraform.tfvars
function New-TFVars {
    param(
        [string]$env,
        [string]$envDir
    )
    
    Write-Status "Creating terraform.tfvars for $env environment..."
    
    # Load environment configuration
    $envConfig = Get-EnvironmentConfig $env
    
    $tfvarsContent = @"
# Environment Configuration
environment = "$env"
project_id  = "$($envConfig.project_id)"
region      = "$($envConfig.region)"
zone        = "$($envConfig.zone)"

# Network Configuration
subnet_cidr = "$($envConfig.subnet_cidr)"

# Compute Configuration
machine_type = "$($envConfig.machine_type)"
disk_size    = $($envConfig.disk_size)
"@
    
    $tfvarsContent | Out-File -FilePath (Join-Path $envDir "terraform.tfvars") -Encoding UTF8
    Write-Success "terraform.tfvars created"
}

# Function to create backend.tf
function New-BackendTF {
    param(
        [string]$env,
        [string]$envDir
    )
    
    Write-Status "Creating backend.tf for $env environment..."
    
    # Load environment configuration
    $envConfig = Get-EnvironmentConfig $env
    
    $backendContent = @"
terraform {
  backend "gcs" {
    bucket  = "$($envConfig.bucket_name)"
    prefix  = "terraform/state"
  }
}
"@
    
    $backendContent | Out-File -FilePath (Join-Path $envDir "backend.tf") -Encoding UTF8
    Write-Success "backend.tf created"
}

# Function to create versions.tf
function New-VersionsTF {
    param(
        [string]$env,
        [string]$envDir
    )
    
    Write-Status "Creating versions.tf for $env environment..."
    
    $versionsContent = @"
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}
"@
    
    $versionsContent | Out-File -FilePath (Join-Path $envDir "versions.tf") -Encoding UTF8
    Write-Success "versions.tf created"
}

# Function to create .tflint.hcl
function New-TFLintHCL {
    param(
        [string]$env,
        [string]$envDir
    )
    
    Write-Status "Creating .tflint.hcl for $env environment..."
    
    $tflintContent = @"
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
"@
    
    $tflintContent | Out-File -FilePath (Join-Path $envDir ".tflint.hcl") -Encoding UTF8
    Write-Success ".tflint.hcl created"
}

# Function to create README.md
function New-Readme {
    param(
        [string]$env,
        [string]$envDir
    )
    
    Write-Status "Creating README.md for $env environment..."
    
    $machineType = switch ($env) {
        "dev" { "e2-micro" }
        "staging" { "e2-small" }
        "prod" { "e2-standard-2" }
    }
    
    $readmeContent = @"
# $env Environment

This directory contains the Terraform configuration for the **$env** environment.

## Files

- `main.tf` - Main Terraform configuration
- `variables.tf` - Variable definitions
- `terraform.tfvars` - Environment-specific variable values
- `backend.tf` - Remote state configuration
- `versions.tf` - Provider and Terraform version constraints
- `.tflint.hcl` - TFLint configuration

## Usage

### Initialize
```bash
terraform init
```

### Plan
```bash
terraform plan
```

### Apply
```bash
terraform apply
```

### Destroy
```bash
terraform destroy
```

## Environment-Specific Configuration

This environment is configured for **$env** with the following characteristics:

- **Project ID**: terraform-$env-project
- **Region**: us-central1
- **Zone**: us-central1-c
- **Machine Type**: $machineType

## Security Notes

- All resources are tagged with the environment name
- Network access is restricted to the subnet CIDR
- Resources follow naming conventions with environment prefixes

## Maintenance

- Run `terraform fmt` to format code
- Run `terraform validate` to check syntax
- Run `tflint` to check for best practices
- Keep provider versions updated
"@
    
    $readmeContent | Out-File -FilePath (Join-Path $envDir "README.md") -Encoding UTF8
    Write-Success "README.md created"
}

# Function to initialize Terraform
function Initialize-Terraform {
    param(
        [string]$env,
        [string]$envDir
    )
    
    Write-Status "Initializing Terraform for $env environment..."
    
    Push-Location $envDir
    
    try {
        # Initialize Terraform
        if (terraform init) {
            Write-Success "Terraform initialized successfully"
        } else {
            Write-Error "Terraform initialization failed"
            return $false
        }
        
        # Validate configuration
        if (terraform validate) {
            Write-Success "Terraform configuration is valid"
        } else {
            Write-Error "Terraform configuration validation failed"
            return $false
        }
        
        # Format code
        terraform fmt -recursive
        Write-Success "Terraform code formatted"
        
        return $true
    }
    finally {
        Pop-Location
    }
}

# Function to setup environment
function Set-Environment {
    param(
        [string]$env,
        [bool]$force
    )
    $envDir = Join-Path $ProjectRoot "environments\$env"
    
    Write-Status "Setting up $env environment..."
    Write-Host "=================================================="
    
    # Check if environment already exists
    if (Test-Path $envDir) {
        if (-not $force) {
            Write-Error "Environment $env already exists"
            Write-Status "Use -Force to overwrite existing environment"
            return $false
        }
        
        Write-Warning "Overwriting existing environment: $env"
        Remove-Item $envDir -Recurse -Force
    }
    
    # Create environment directory
    New-EnvironmentDirectory $env
    
    # Create configuration files
    New-MainTF $env $envDir
    New-VariablesTF $env $envDir
    New-TFVars $env $envDir
    New-BackendTF $env $envDir
    New-VersionsTF $env $envDir
    New-TFLintHCL $env $envDir
    New-Readme $env $envDir
    
    # Initialize Terraform
    if (Initialize-Terraform $env $envDir) {
        Write-Host "=================================================="
        Write-Success "$env environment setup completed successfully!"
        
        Write-Status "Next steps:"
        Write-Host "1. Review the configuration in $envDir/"
        Write-Host "2. Update terraform.tfvars with your specific values"
        Write-Host "3. Run: python scripts/run validate $env"
        Write-Host "4. Run: python scripts/run deploy $env -DryRun"
        Write-Host "5. Run: python scripts/run deploy $env"
        
        return $true
    } else {
        Write-Host "=================================================="
        Write-Error "$env environment setup failed"
        return $false
    }
}

# Main execution
if ($Help) {
    Show-Usage
    exit 0
}

# Check dependencies
Test-Dependencies

# Check production permissions
Test-ProductionPermissions $Environment

# Setup environment
Set-Environment $Environment $Force 