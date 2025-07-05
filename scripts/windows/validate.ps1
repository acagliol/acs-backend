# Terraform Validation Script (PowerShell)
# Usage: .\scripts\windows\validate.ps1 [dev|staging|prod|all] [-Fix] [-Strict] [-Help]

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod", "all")]
    [string]$Environment,
    
    [switch]$Fix,
    [switch]$Strict,
    [switch]$Help
)

# Script configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$ConfigFile = Join-Path $ProjectRoot "config\environments.json"
$Environments = @("dev", "staging", "prod")

# Validation results
$script:ValidationErrors = 0
$script:ValidationWarnings = 0

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
    $script:ValidationWarnings++
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    $script:ValidationErrors++
}

# Function to show usage
function Show-Usage {
    Write-Host @"
Usage: $($MyInvocation.MyCommand.Name) [ENVIRONMENT] [OPTIONS]

ENVIRONMENTS:
    dev       - Validate development environment
    staging   - Validate staging environment
    prod      - Validate production environment
    all       - Validate all environments

OPTIONS:
    -Fix      - Automatically fix formatting issues
    -Strict   - Treat warnings as errors
    -Help     - Show this help message

EXAMPLES:
    $($MyInvocation.MyCommand.Name) dev              # Validate dev environment
    $($MyInvocation.MyCommand.Name) all -Fix         # Validate all environments and fix formatting
    $($MyInvocation.MyCommand.Name) staging -Strict  # Validate staging with strict mode

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
    
    # Optional dependencies
    if (Get-Command checkov -ErrorAction SilentlyContinue) {
        $script:CheckovAvailable = $true
    } else {
        $script:CheckovAvailable = $false
        Write-Warning "Checkov not found - security scanning will be skipped"
    }
    
    if (Get-Command tflint -ErrorAction SilentlyContinue) {
        $script:TFLintAvailable = $true
    } else {
        $script:TFLintAvailable = $false
        Write-Warning "TFLint not found - linting will be skipped"
    }
    
    if ($missingDeps.Count -gt 0) {
        Write-Error "Missing required dependencies: $($missingDeps -join ', ')"
        Write-Error "Please install the missing tools and try again."
        exit 1
    }
}

# Function to validate environment configuration
function Test-EnvironmentConfig {
    param([string]$env)
    
    # Check if environment exists in config
    if (-not (Test-Path $ConfigFile)) {
        Write-Error "Configuration file not found: $ConfigFile"
        return $false
    }
    
    try {
        $config = Get-Content $ConfigFile | ConvertFrom-Json
        if (-not $config.environments.$env) {
            Write-Error "Environment '$env' not found in configuration file"
            return $false
        }
        
        # Check if main.tf exists in project root
        if (-not (Test-Path (Join-Path $ProjectRoot "main.tf"))) {
            Write-Error "main.tf not found in project root"
            return $false
        }
        
        Write-Success "Environment configuration validated"
        return $true
    } catch {
        Write-Error "Failed to parse configuration file: $($_.Exception.Message)"
        return $false
    }
}

# Function to validate Terraform syntax
function Test-TerraformSyntax {
    param(
        [string]$env,
        [bool]$fix
    )
    
    Write-Status "Validating Terraform syntax for $env environment..."
    
    Push-Location $ProjectRoot
    
    try {
        # Get environment configuration for backend setup
        $config = Get-Content $ConfigFile | ConvertFrom-Json
        $envConfig = $config.environments.$env
        $bucketName = $envConfig.bucket_name
        
        # Check if .terraform directory exists, if not initialize
        if (-not (Test-Path ".terraform")) {
            Write-Status "Initializing Terraform for validation..."
            $backendConfig = @(
                "-backend-config=bucket=$bucketName",
                "-backend-config=prefix=terraform/state"
            )
            terraform init @backendConfig
        }
        
        # Validate Terraform configuration
        if (terraform validate) {
            Write-Success "Terraform syntax validation passed for $env"
        } else {
            Write-Error "Terraform syntax validation failed for $env"
            return $false
        }
        
        # Check formatting
        $formatResult = terraform fmt -check -recursive 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Terraform formatting is correct for $env"
        } else {
            if ($fix) {
                Write-Status "Fixing Terraform formatting for $env..."
                terraform fmt -recursive
                Write-Success "Terraform formatting fixed for $env"
            } else {
                Write-Warning "Terraform formatting issues found in $env"
                Write-Status "Run with -Fix to automatically fix formatting"
            }
        }
        
        return $true
    }
    finally {
        Pop-Location
    }
}

# Function to validate provider compatibility
function Test-ProviderCompatibility {
    param([string]$env)
    
    Write-Status "Validating provider compatibility for $env environment..."
    
    Push-Location $ProjectRoot
    
    try {
        # Check provider versions in main.tf
        if (Test-Path "main.tf") {
            Write-Status "Checking provider version constraints..."
            
            # Extract provider versions and check compatibility
            $mainContent = Get-Content "main.tf" -Raw
            if ($mainContent -match 'version\s*=\s*["'']~>\s*[0-9]+\.[0-9]+') {
                Write-Success "Google provider version constraint found"
            } else {
                Write-Warning "No specific Google provider version constraint found"
            }
        } else {
            Write-Warning "main.tf not found - provider version constraints not enforced"
        }
        
        return $true
    }
    finally {
        Pop-Location
    }
}

# Function to validate variable definitions
function Test-Variables {
    param([string]$env)
    
    Write-Status "Validating variable definitions for $env environment..."
    
    Push-Location $ProjectRoot
    
    try {
        # Check if variables.tf exists
        if (-not (Test-Path "variables.tf")) {
            Write-Warning "variables.tf not found in project root"
            return $true
        }
        
        # Check for required variables
        $requiredVars = @("environment", "project_id", "region")
        $variablesContent = Get-Content "variables.tf" -Raw
        
        foreach ($var in $requiredVars) {
            if ($variablesContent -notmatch "variable `"$var`"") {
                Write-Warning "Required variable '$var' not found in variables.tf"
            }
        }
        
        # Check for variable validation
        $varsWithValidation = ([regex]::Matches($variablesContent, "validation \{")).Count
        $totalVars = ([regex]::Matches($variablesContent, "variable `"")).Count
        
        if ($totalVars -gt 0) {
            $validationPercentage = [math]::Round(($varsWithValidation * 100) / $totalVars)
            if ($validationPercentage -lt 50) {
                Write-Warning "Only $validationPercentage% of variables have validation rules"
            } else {
                Write-Success "Variable validation coverage: $validationPercentage%"
            }
        }
        
        return $true
    }
    finally {
        Pop-Location
    }
}

# Function to validate terraform.tfvars
function Test-TFVars {
    param([string]$env)
    
    Write-Status "Validating terraform.tfvars for $env environment..."
    
    Push-Location $ProjectRoot
    
    try {
        if (-not (Test-Path "terraform.tfvars")) {
            Write-Warning "terraform.tfvars not found in project root"
            return $true
        }
        
        # Check for sensitive values in tfvars
        $tfvarsContent = Get-Content "terraform.tfvars" -Raw
        if ($tfvarsContent -match "(?i)(password|secret|key|token)") {
            Write-Error "Sensitive values found in terraform.tfvars"
            Write-Error "Use environment variables or secret management instead"
            return $false
        }
        
        # Check for empty values
        if ($tfvarsContent -match "= `"`"") {
            Write-Warning "Empty string values found in terraform.tfvars"
        }
        
        return $true
    }
    finally {
        Pop-Location
    }
}

# Function to run TFLint (if available)
function Invoke-TFLint {
    param([string]$env)
    
    if (-not $script:TFLintAvailable) {
        return $true
    }
    
    Write-Status "Running TFLint for $env environment..."
    
    Push-Location $ProjectRoot
    
    try {
        # Check if .tflint.hcl exists
        if (-not (Test-Path ".tflint.hcl")) {
            Write-Warning ".tflint.hcl configuration not found in project root"
            return $true
        }
        
        if (tflint) {
            Write-Success "TFLint validation passed for $env"
            return $true
        } else {
            Write-Error "TFLint validation failed for $env"
            return $false
        }
    }
    finally {
        Pop-Location
    }
}

# Function to run Checkov security scanning (if available)
function Invoke-Checkov {
    param([string]$env)
    
    if (-not $script:CheckovAvailable) {
        return $true
    }
    
    Write-Status "Running Checkov security scan for $env environment..."
    
    Push-Location $ProjectRoot
    
    try {
        # Run Checkov with specific frameworks
        $checkovResult = checkov -d . --framework terraform --output cli --compact 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Checkov security scan passed for $env"
            return $true
        } else {
            Write-Warning "Checkov security scan found issues in $env"
            Write-Status "Review the security findings above"
            return $true  # Don't fail validation for security warnings
        }
    }
    finally {
        Pop-Location
    }
}

# Function to validate backend configuration
function Test-Backend {
    param([string]$env)
    
    Write-Status "Validating backend configuration for $env environment..."
    
    Push-Location $ProjectRoot
    
    try {
        # Check for backend.tf in project root
        if (-not (Test-Path "backend.tf")) {
            Write-Warning "backend.tf not found in project root"
            return $true
        }
        
        # Check for remote backend configuration
        $backendContent = Get-Content "backend.tf" -Raw
        if ($backendContent -match 'backend "gcs"') {
            Write-Success "GCS backend configuration found for $env"
            
            # Extract bucket name
            if ($backendContent -match 'bucket\s*=\s*"([^"]*)"') {
                $bucketName = $matches[1]
                Write-Status "Backend bucket: $bucketName"
            }
        } else {
            Write-Warning "Remote backend configuration not found for $env"
        }
        
        return $true
    }
    finally {
        Pop-Location
    }
}

# Function to validate environment-specific configuration
function Test-EnvironmentSpecificConfig {
    param([string]$env)
    
    Write-Status "Validating environment-specific configuration for $env..."
    
    Push-Location $ProjectRoot
    
    try {
        # Check for environment-specific naming
        if (Test-Path "main.tf") {
            $mainContent = Get-Content "main.tf" -Raw
            if ($mainContent -match '\$\{var\.environment\}') {
                Write-Success "Environment-aware naming found in $env"
            } else {
                Write-Warning "Environment-aware naming not found in $env"
            }
            
            # Check for proper tagging
            if ($mainContent -match "tags\s*=") {
                Write-Success "Resource tagging found in $env"
            } else {
                Write-Warning "Resource tagging not found in $env"
            }
        }
        
        return $true
    }
    finally {
        Pop-Location
    }
}

# Function to validate a single environment
function Test-SingleEnvironment {
    param(
        [string]$env,
        [bool]$fix,
        [bool]$strict
    )
    
    Write-Status "Starting validation for $env environment..."
    Write-Host "=================================================="
    
    $envErrors = 0
    
    # Validate environment configuration
    if (-not (Test-EnvironmentConfig $env)) {
        $envErrors++
        return $false
    }
    
    # Run all validation checks
    if (-not (Test-TerraformSyntax $env $fix)) { $envErrors++ }
    if (-not (Test-ProviderCompatibility $env)) { $envErrors++ }
    if (-not (Test-Variables $env)) { $envErrors++ }
    if (-not (Test-TFVars $env)) { $envErrors++ }
    if (-not (Invoke-TFLint $env)) { $envErrors++ }
    if (-not (Invoke-Checkov $env)) { $envErrors++ }
    if (-not (Test-Backend $env)) { $envErrors++ }
    if (-not (Test-EnvironmentSpecificConfig $env)) { $envErrors++ }
    
    Write-Host "=================================================="
    
    if ($envErrors -eq 0) {
        Write-Success "Validation completed for $env environment"
        return $true
    } else {
        Write-Error "Validation failed for $env environment ($envErrors errors)"
        return $false
    }
}

# Function to validate all environments
function Test-AllEnvironments {
    param(
        [bool]$fix,
        [bool]$strict
    )
    
    Write-Status "Validating all environments..."
    
    $allPassed = $true
    
    foreach ($env in $Environments) {
        if (-not (Test-SingleEnvironment $env $fix $strict)) {
            $allPassed = $false
        }
        Write-Host ""
    }
    
    if ($allPassed) {
        Write-Success "All environments validated successfully!"
        return $true
    } else {
        Write-Error "Some environments failed validation"
        return $false
    }
}

# Function to print validation summary
function Show-ValidationSummary {
    Write-Host ""
    Write-Host "=================================================="
    Write-Host "VALIDATION SUMMARY"
    Write-Host "=================================================="
    Write-Host "Errors: $script:ValidationErrors"
    Write-Host "Warnings: $script:ValidationWarnings"
    Write-Host "=================================================="
    
    if ($script:ValidationErrors -eq 0) {
        Write-Success "Validation completed successfully!"
        exit 0
    } else {
        Write-Error "Validation completed with errors"
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

# Run validation
if ($Environment -eq "all") {
    Test-AllEnvironments $Fix $Strict
} else {
    Test-SingleEnvironment $Environment $Fix $Strict
}

# Print summary
Show-ValidationSummary 