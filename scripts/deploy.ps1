# =============================================================================
# SIMPLIFIED DEPLOYMENT SCRIPT (Windows)
# =============================================================================
# This script deploys to any environment using the consolidated main.tf
# Usage: .\deploy.ps1 -Environment dev|staging|prod

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

Write-Host "Deploying to $Environment Environment..." -ForegroundColor $EnvConfig.Color

# Production safety check
if ($EnvConfig.RequireConfirmation) {
    Write-Host "This will deploy to $Environment environment" -ForegroundColor $EnvConfig.Color
    $confirmation = Read-Host "Are you sure you want to continue? (yes/no)"
    if ($confirmation -ne "yes") {
        Write-Host "Deployment cancelled by user." -ForegroundColor Red
        exit 1
    }
}

# Check if we're in the correct directory
$ProjectRoot = Get-Location
if (-not (Test-Path "main.tf")) {
    # Try going up one level if we're in the scripts directory
    if (Test-Path "..\main.tf") {
        Set-Location ".."
        $ProjectRoot = Get-Location
    } else {
        Write-Host "Error: main.tf not found. Please run this script from the project root directory." -ForegroundColor Red
        exit 1
    }
}

# Check if environment configuration exists
$envConfigPath = "environments\$Environment.json"
if (-not (Test-Path $envConfigPath)) {
    Write-Host "Error: Environment configuration file not found: $envConfigPath" -ForegroundColor Red
    exit 1
}

# Check if backend configuration exists
if (-not (Test-Path $EnvConfig.BackendFile)) {
    Write-Host "Error: Backend configuration file not found: $($EnvConfig.BackendFile)" -ForegroundColor Red
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
    Write-Host "Error setting GCP project: $_" -ForegroundColor Red
    Write-Host "Make sure gcloud is installed and you're authenticated: gcloud auth login" -ForegroundColor Cyan
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
    Write-Host "Error copying backend configuration: $_" -ForegroundColor Red
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
    Write-Host "Error initializing Terraform: $_" -ForegroundColor Red
    exit 1
}

# Format and validate configuration
Write-Host "Formatting and validating configuration..." -ForegroundColor Yellow
try {
    terraform fmt
    terraform validate
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform validation failed"
    }
} catch {
    Write-Host "Error validating Terraform configuration: $_" -ForegroundColor Red
    exit 1
}

# Plan deployment
Write-Host "Planning deployment..." -ForegroundColor Yellow
try {
    terraform plan -var="environment=$Environment" -out=tfplan
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform plan failed"
    }
} catch {
    Write-Host "Error planning deployment: $_" -ForegroundColor Red
    exit 1
}

# Create state backup before applying
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$username = $env:USERNAME
$backupDir = "backups\$Environment\$timestamp-$username"
$backupFile = "$backupDir\terraform.tfstate.backup.$timestamp"

Write-Host "Creating state backup..." -ForegroundColor Yellow
try {
    # Create backup directory
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    
    # Create backup manifest
    $backupManifest = @{
        timestamp = $timestamp
        environment = $Environment
        username = $username
        backup_file = $backupFile
        terraform_version = (terraform version -json | ConvertFrom-Json).terraform_version
        project = $EnvConfig.Project
    }
    
    $backupManifest | ConvertTo-Json | Out-File "$backupDir\backup_manifest.$timestamp.json"
    
    # Pull current state and save as backup
    terraform state pull > $backupFile
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create state backup"
    }
    
    Write-Host "State backup created: $backupFile" -ForegroundColor Green
} catch {
    Write-Host "Error creating state backup: $_" -ForegroundColor Red
    Write-Host "Continuing without backup (not recommended for production)" -ForegroundColor Yellow
}

# Apply changes
Write-Host "Applying changes..." -ForegroundColor Yellow
try {
    terraform apply tfplan
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform apply failed"
    }
} catch {
    Write-Host "Error applying changes: $_" -ForegroundColor Red
    
    # Attempt rollback if backup exists
    if (Test-Path $backupFile) {
        Write-Host "Attempting to rollback to previous state..." -ForegroundColor Yellow
        try {
            # Push the backup state back
            Get-Content $backupFile | terraform state push -
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Rollback successful! State restored to backup from $timestamp" -ForegroundColor Green
                Write-Host "Backup location: $backupFile" -ForegroundColor Cyan
            } else {
                Write-Host "Rollback failed! Manual intervention required." -ForegroundColor Red
                Write-Host "Backup state available at: $backupFile" -ForegroundColor Cyan
                Write-Host "You may need to manually restore the state or destroy/recreate resources." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "Rollback failed with error: $_" -ForegroundColor Red
            Write-Host "Backup state available at: $backupFile" -ForegroundColor Cyan
            Write-Host "Manual intervention required to restore state." -ForegroundColor Yellow
        }
    } else {
        Write-Host "No backup available for rollback. Manual intervention required." -ForegroundColor Red
    }
    
    # Clean up plan file
    if (Test-Path "tfplan") {
        Remove-Item "tfplan"
    }
    
    exit 1
}

# Clean up plan file
if (Test-Path "tfplan") {
    Remove-Item "tfplan"
}

Write-Host "$Environment deployment completed successfully!" -ForegroundColor Green
Write-Host "Run 'terraform output' to see deployment results." -ForegroundColor Cyan 