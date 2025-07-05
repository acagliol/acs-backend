# Preflight Check Script (PowerShell)
# Usage: .\scripts\windows\preflight.ps1 [dev|staging|prod]

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,
    
    [switch]$Help
)

# Script configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$ConfigFile = Join-Path $ProjectRoot "config\environments.json"
$Environments = @("dev", "staging", "prod")

# Preflight results
$script:PreflightErrors = 0
$script:PreflightWarnings = 0

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
    $script:PreflightWarnings++
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    $script:PreflightErrors++
}

# Function to show usage
function Show-Usage {
    Write-Host @"
Usage: $($MyInvocation.MyCommand.Name) [ENVIRONMENT]

ENVIRONMENTS:
    dev       - Run preflight checks for development environment
    staging   - Run preflight checks for staging environment
    prod      - Run preflight checks for production environment

EXAMPLES:
    $($MyInvocation.MyCommand.Name) dev      # Run preflight checks for dev
    $($MyInvocation.MyCommand.Name) staging  # Run preflight checks for staging
    $($MyInvocation.MyCommand.Name) prod     # Run preflight checks for prod

"@
}

# Function to load environment configuration
function Get-EnvironmentConfig {
    param([string]$env)
    
    if (-not (Test-Path $ConfigFile)) {
        Write-Error "Configuration file not found: $ConfigFile"
        return $null
    }
    
    try {
        $config = Get-Content $ConfigFile | ConvertFrom-Json
        if ($config.environments.$env) {
            return $config.environments.$env
        } else {
            Write-Error "Environment '$env' not found in configuration file"
            return $null
        }
    } catch {
        Write-Error "Failed to load configuration file: $($_.Exception.Message)"
        return $null
    }
}

# Function to check dependencies
function Test-Dependencies {
    Write-Status "Checking required dependencies..."
    
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
        return $false
    }
    
    # Check Terraform version
    try {
        $tfVersion = (terraform version -json | ConvertFrom-Json).terraform_version
        Write-Status "Terraform version: $tfVersion"
    } catch {
        Write-Status "Terraform version: unknown"
    }
    
    # Check gcloud version
    try {
        $gcloudVersion = gcloud version --format="value(google_cloud_sdk_version)" 2>$null
        Write-Status "Google Cloud SDK version: $gcloudVersion"
    } catch {
        Write-Status "Google Cloud SDK version: unknown"
    }
    
    Write-Success "All required dependencies are available"
    return $true
}

# Function to check Google Cloud authentication
function Test-GCloudAuth {
    param([string]$env)
    
    Write-Status "Checking Google Cloud authentication..."
    
    try {
        $activeAccount = gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>$null
        if (-not $activeAccount) {
            Write-Error "No active Google Cloud authentication found"
            Write-Status "Run 'gcloud auth login' to authenticate"
            return $false
        }
        
        Write-Status "Active account: $activeAccount"
        
        # Get project ID from config
        $envConfig = Get-EnvironmentConfig $env
        if (-not $envConfig) {
            return $false
        }
        
        $projectId = $envConfig.project_id
        
        if ($projectId) {
            try {
                gcloud projects describe $projectId 2>$null | Out-Null
                Write-Success "Access to project $projectId confirmed"
            } catch {
                Write-Warning "Cannot access project $projectId"
                Write-Status "You may not have the necessary permissions"
            }
        }
        
        Write-Success "Google Cloud authentication is valid"
        return $true
    } catch {
        Write-Error "Failed to check Google Cloud authentication: $($_.Exception.Message)"
        return $false
    }
}

# Function to check environment-specific files
function Test-EnvironmentFiles {
    param([string]$env)
    
    Write-Status "Checking environment configuration for $env..."
    
    # Check if environment exists in config
    $envConfig = Get-EnvironmentConfig $env
    if (-not $envConfig) {
        return $false
    }
    
    # Check required fields
    $requiredFields = @("project_id", "bucket_name", "region", "zone", "machine_type", "subnet_cidr", "disk_size")
    foreach ($field in $requiredFields) {
        if (-not $envConfig.$field) {
            Write-Error "Missing required field '$field' for environment '$env'"
            return $false
        }
    }
    
    # Check if main.tf exists in project root
    if (-not (Test-Path (Join-Path $ProjectRoot "main.tf"))) {
        Write-Error "main.tf not found in project root"
        return $false
    }
    
    # Check if variables.tf exists
    if (-not (Test-Path (Join-Path $ProjectRoot "variables.tf"))) {
        Write-Error "variables.tf not found in project root"
        return $false
    }
    
    Write-Success "Environment configuration is valid"
    return $true
}

# Function to check for sensitive information
function Test-SensitiveInfo {
    param([string]$env)
    
    Write-Status "Checking for sensitive information in $env environment..."
    
    Push-Location $ProjectRoot
    
    try {
        # Check for hardcoded secrets in main.tf
        if (Test-Path "main.tf") {
            $mainContent = Get-Content "main.tf" -Raw
            if ($mainContent -match "(?i)(password|secret|key|token|api_key)") {
                Write-Error "Sensitive information found in main.tf"
                Write-Error "Use environment variables or secret management instead"
                return $false
            }
        }
        
        Write-Success "No sensitive information found in configuration files"
        return $true
    }
    finally {
        Pop-Location
    }
}

# Function to run preflight checks for an environment
function Invoke-PreflightChecks {
    param([string]$env)
    
    Write-Status "Starting preflight checks for $env environment..."
    Write-Host "=================================================="
    
    # Run essential preflight checks
    $allChecksPassed = $true
    
    if (-not (Test-Dependencies)) { 
        $allChecksPassed = $false 
    }
    
    if (-not (Test-GCloudAuth $env)) { 
        $allChecksPassed = $false 
    }
    
    if (-not (Test-EnvironmentFiles $env)) { 
        $allChecksPassed = $false 
    }
    
    if (-not (Test-SensitiveInfo $env)) { 
        $allChecksPassed = $false 
    }
    
    Write-Host "=================================================="
    
    if ($allChecksPassed) {
        Write-Success "Preflight checks completed for $env environment"
        return $true
    } else {
        Write-Error "Preflight checks failed for $env environment"
        return $false
    }
}

# Function to print preflight summary
function Show-PreflightSummary {
    Write-Host ""
    Write-Host "=================================================="
    Write-Host "PREFLIGHT SUMMARY"
    Write-Host "=================================================="
    Write-Host "Errors: $script:PreflightErrors"
    Write-Host "Warnings: $script:PreflightWarnings"
    Write-Host "=================================================="
    
    if ($script:PreflightErrors -eq 0) {
        Write-Success "Preflight checks passed! Ready for deployment."
        exit 0
    } else {
        Write-Error "Preflight checks failed. Please fix the errors before deployment."
        exit 1
    }
}

# Main execution
if ($Help) {
    Show-Usage
    exit 0
}

# Run preflight checks
Invoke-PreflightChecks $Environment

# Print summary
Show-PreflightSummary 