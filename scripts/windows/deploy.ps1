# Terraform Deployment Script (PowerShell)
# Usage: .\scripts\windows\deploy.ps1 [dev|staging|prod] [--force] [--dry-run]

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,
    
    [switch]$Force,
    [switch]$DryRun,
    [switch]$Help
)

# Script configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$ConfigFile = Join-Path $ProjectRoot "config\environments.json"
$Environments = @("dev", "staging", "prod")

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
    dev       - Deploy to development environment
    staging   - Deploy to staging environment
    prod      - Deploy to production environment (requires approval)

OPTIONS:
    -Force     - Skip confirmation prompts
    -DryRun    - Show what would be deployed without making changes
    -Help      - Show this help message

EXAMPLES:
    $($MyInvocation.MyCommand.Name) dev                    # Deploy to dev environment
    $($MyInvocation.MyCommand.Name) staging -DryRun        # Show staging deployment plan
    $($MyInvocation.MyCommand.Name) prod -Force            # Deploy to prod (skips confirmation)

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

# Function to check if environment is enabled
function Test-EnvironmentEnabled {
    param([string]$env)
    
    if ($env -eq "prod") {
        Write-Warning "Production environment deployment - extra care required"
        Write-Warning "Ensure you have proper approvals before proceeding"
    }
    
    # Validate that the environment exists in the config
    try {
        $envConfig = Get-EnvironmentConfig $env
        if (-not $envConfig) {
            Write-Error "Environment '$env' not found in configuration"
            exit 1
        }
    } catch {
        Write-Error "Failed to validate environment '$env': $($_.Exception.Message)"
        exit 1
    }
}

# Function to run preflight checks
function Invoke-PreflightChecks {
    param([string]$env)
    Write-Status "Running preflight checks for $env environment..."
    
    $preflightScript = Join-Path $ScriptDir "preflight.ps1"
    if (Test-Path $preflightScript) {
        & $preflightScript $env
    } else {
        Write-Warning "Preflight script not found, skipping checks"
    }
}

# Function to backup current state
function Backup-State {
    param([string]$env)
    Write-Status "Creating state backup for $env environment..."
    
    $backupScript = Join-Path $ScriptDir "backup-state.ps1"
    if (Test-Path $backupScript) {
        & $backupScript $env
    } else {
        Write-Warning "Backup script not found, skipping state backup"
    }
}

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

# Function to deploy to environment
function Deploy-Environment {
    param(
        [string]$env,
        [bool]$force,
        [bool]$dryRun
    )
    
    Write-Status "Deploying to $env environment..."
    
    # Change to project root
    Push-Location $ProjectRoot
    
    try {
        # Get environment configuration for backend setup
        $envConfig = Get-EnvironmentConfig $env
        $bucketName = $envConfig.bucket_name
        
        # Initialize Terraform with backend configuration
        if (-not (Test-Path ".terraform")) {
            Write-Status "Initializing Terraform..."
            $backendConfig = @(
                "-backend-config=bucket=$bucketName",
                "-backend-config=prefix=terraform/state"
            )
            terraform init @backendConfig
        }
        
        # Validate Terraform configuration
        Write-Status "Validating Terraform configuration..."
        if (-not (terraform validate)) {
            Write-Error "Terraform validation failed"
            exit 1
        }
        
        # Format Terraform code
        Write-Status "Formatting Terraform code..."
        terraform fmt -recursive
        
        # Show plan
        Write-Status "Generating deployment plan..."
        terraform plan -var="environment=$env" -out=tfplan
        
        if ($dryRun) {
            Write-Success "Dry run completed. Review the plan above."
            Write-Status "To apply changes, run: python scripts/run deploy $env"
            return
        }
        
        # Confirm deployment (unless -Force is used)
        if (-not $force) {
            Write-Host ""
            Write-Warning "You are about to deploy to the $env environment."
            Write-Warning "This will modify infrastructure resources."
            
            if ($env -eq "prod") {
                Write-Warning "⚠️  PRODUCTION DEPLOYMENT - This affects live systems!"
                Write-Host ""
                $confirmation = Read-Host "Type 'PRODUCTION' to confirm"
                if ($confirmation -ne "PRODUCTION") {
                    Write-Error "Production deployment cancelled"
                    exit 1
                }
            } else {
                $confirmation = Read-Host "Do you want to continue? (y/N)"
                if ($confirmation -notmatch "^[Yy]$") {
                    Write-Error "Deployment cancelled"
                    exit 1
                }
            }
        }
        
        # Apply changes
        Write-Status "Applying Terraform changes..."
        if (terraform apply tfplan) {
            Write-Success "Deployment to $env completed successfully!"
            
            # Show outputs
            Write-Status "Deployment outputs:"
            terraform output
        } else {
            Write-Error "Deployment to $env failed!"
            Write-Status "Check the error messages above and fix any issues."
            Write-Status "You can run 'python scripts/run rollback $env' if needed."
            exit 1
        }
        
        # Clean up plan file
        if (Test-Path "tfplan") {
            Remove-Item "tfplan"
        }
    }
    finally {
        Pop-Location
    }
}

# Function to check active gcloud project matches environment
function Check-GCloudProject {
    param([string]$env)
    $envConfig = Get-EnvironmentConfig $env
    $expectedProject = $envConfig.project_id
    $activeProject = $(gcloud config get-value project 2>$null).Trim()
    if ($activeProject -ne $expectedProject) {
        Write-Error "Active gcloud project ($activeProject) does not match environment project_id ($expectedProject)."
        Write-Error "Run: gcloud config set project $expectedProject"
        exit 1
    }
}

# Main execution
if ($Help) {
    Show-Usage
    exit 0
}

# Check dependencies
Test-Dependencies

# Check if environment is enabled
Test-EnvironmentEnabled $Environment

# Check gcloud project matches environment
Check-GCloudProject $Environment

# Run preflight checks
Invoke-PreflightChecks $Environment

# Backup current state
Backup-State $Environment

# Deploy to environment
Deploy-Environment $Environment $Force $DryRun 