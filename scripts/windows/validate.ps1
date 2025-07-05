# Terraform Validation Script (PowerShell) - Simplified
# Usage: .\scripts\windows\validate.ps1 [dev|staging|prod]

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment
)

# Script configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

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

# Function to load environment configuration
function Get-EnvironmentConfig {
    param([string]$env)
    
    $envConfigFile = Join-Path $ProjectRoot "environments\$env.json"
    
    if (-not (Test-Path $envConfigFile)) {
        Write-Error "Environment configuration file not found: $envConfigFile"
        exit 1
    }
    
    try {
        $config = Get-Content $envConfigFile | ConvertFrom-Json
        return $config
    } catch {
        Write-Error "Failed to load environment configuration file: $($_.Exception.Message)"
        exit 1
    }
}

# Main execution
Write-Status "Validating Terraform configuration for $Environment environment..."

# Check dependencies
$missingDeps = @()
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) { $missingDeps += "terraform" }
if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) { $missingDeps += "gcloud" }

if ($missingDeps.Count -gt 0) {
    Write-Error "Missing required dependencies: $($missingDeps -join ', ')"
    exit 1
}

# Change to project root
Push-Location $ProjectRoot

try {
    # Get environment configuration
    $envConfig = Get-EnvironmentConfig $Environment
    
    # Check if terraform init is needed
    if (-not (Test-Path ".terraform")) {
        Write-Error "Terraform not initialized. Run 'terraform init' before validation."
        exit 1
    }
    
    # Validate Terraform configuration
    Write-Status "Running terraform validate..."
    if (terraform validate) {
        Write-Success "Terraform validation passed"
    } else {
        Write-Error "Terraform validation failed"
        exit 1
    }
    
    # Check formatting
    Write-Status "Checking terraform formatting..."
    $formatResult = terraform fmt -check -recursive 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Terraform formatting is correct"
    } else {
        Write-Warning "Terraform formatting issues found"
        Write-Status "Run 'terraform fmt -recursive' to fix formatting"
    }
    
    Write-Success "Validation completed for $Environment environment"
}
finally {
    Pop-Location
} 