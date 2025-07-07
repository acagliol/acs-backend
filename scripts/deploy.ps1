# =============================================================================
# UNIFIED DEPLOYMENT SCRIPT
# =============================================================================
# This script deploys to any environment (dev, staging, prod)
# Usage: .\scripts\deploy.ps1 -Environment dev|staging|prod

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment
)

# Environment configuration
$Config = @{
    "dev" = @{
        Project = "acs-dev-464702"
        BackendFile = "config\backend-dev.tf"
        Color = "Green"
        RequireConfirmation = $false
    }
    "staging" = @{
        Project = "acs-staging-464702"
        BackendFile = "config\backend-staging.tf"
        Color = "Yellow"
        RequireConfirmation = $true
    }
    "prod" = @{
        Project = "acs-prod-464702"
        BackendFile = "config\backend-prod.tf"
        Color = "Red"
        RequireConfirmation = $true
    }
}

$EnvConfig = $Config[$Environment]

Write-Host "🚀 Deploying to $Environment Environment..." -ForegroundColor $EnvConfig.Color

# Production safety check
if ($EnvConfig.RequireConfirmation) {
    $confirmation = Read-Host "Are you sure you want to deploy to $Environment environment? (yes/no)"
    if ($confirmation -ne "yes") {
        Write-Host "❌ Deployment cancelled by user." -ForegroundColor Red
        exit 1
    }
}

# Check if we're in the correct directory
if (-not (Test-Path "main-independent.tf")) {
    Write-Host "❌ Error: main-independent.tf not found. Please run this script from the project root directory." -ForegroundColor Red
    exit 1
}

# Check if environment configuration exists
$envConfigPath = "environments\$Environment.json"
if (-not (Test-Path $envConfigPath)) {
    Write-Host "❌ Error: Environment configuration file not found: $envConfigPath" -ForegroundColor Red
    exit 1
}

# Set the correct project
Write-Host "Setting GCP project to $($EnvConfig.Project)..." -ForegroundColor Yellow
try {
    gcloud config set project $EnvConfig.Project
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to set GCP project"
    }
} catch {
    Write-Host "❌ Error setting GCP project: $_" -ForegroundColor Red
    exit 1
}

# Copy the backend configuration
Write-Host "Setting up $Environment backend configuration..." -ForegroundColor Yellow
try {
    Copy-Item $EnvConfig.BackendFile "backend.tf" -Force
    if (-not (Test-Path "backend.tf")) {
        throw "Failed to copy backend configuration"
    }
} catch {
    Write-Host "❌ Error copying backend configuration: $_" -ForegroundColor Red
    exit 1
}

# Initialize Terraform
Write-Host "Initializing Terraform..." -ForegroundColor Yellow
try {
    terraform init
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform initialization failed"
    }
} catch {
    Write-Host "❌ Error initializing Terraform: $_" -ForegroundColor Red
    exit 1
}

# Validate configuration
Write-Host "Validating configuration..." -ForegroundColor Yellow
try {
    terraform validate
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform validation failed"
    }
} catch {
    Write-Host "❌ Error validating Terraform configuration: $_" -ForegroundColor Red
    exit 1
}

# Plan deployment
Write-Host "Planning deployment..." -ForegroundColor Yellow
try {
    terraform plan -var="environment=$Environment"
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform plan failed"
    }
} catch {
    Write-Host "❌ Error planning deployment: $_" -ForegroundColor Red
    exit 1
}

# Apply changes
Write-Host "Applying changes..." -ForegroundColor Yellow
try {
    terraform apply -var="environment=$Environment" -auto-approve
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform apply failed"
    }
} catch {
    Write-Host "❌ Error applying changes: $_" -ForegroundColor Red
    exit 1
}

Write-Host "✅ $Environment deployment completed successfully!" -ForegroundColor Green 