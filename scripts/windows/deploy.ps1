# Terraform Deployment Script (PowerShell) - Phase-Based Deployment
# Usage: .\scripts\windows\deploy.ps1 [dev|staging|prod] [--force] [--dry-run] [--phase1] [--phase2]
# 
# Phase 1: Independent resources (main-independent.tf only)
#   - Creates temporary workspace with only main-independent.tf
#   - Deploys all resources defined in main-independent.tf
#   - Includes Firestore database and other independent resources
# 
# Phase 2: Dependent resources (main-dependent.tf only)
#   - Creates temporary workspace with only main-dependent.tf
#   - Deploys all resources defined in main-dependent.tf
#   - Includes all modules and dependent infrastructure resources
# 
# Examples:
#   .\scripts\windows\deploy.ps1 dev                    # Deploy both phases to dev
#   .\scripts\windows\deploy.ps1 dev -Phase1            # Deploy only Phase 1 (independent resources) to dev
#   .\scripts\windows\deploy.ps1 dev -Phase2            # Deploy only Phase 2 (dependent resources) to dev
#   .\scripts\windows\deploy.ps1 dev -DryRun            # Dry run both phases
#   .\scripts\windows\deploy.ps1 dev -Phase1 -DryRun    # Dry run only Phase 1

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,
    
    [switch]$Force,
    [switch]$DryRun,
    [switch]$Phase1,
    [switch]$Phase2
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

# Function to show a simple spinner while a job runs
function Show-Spinner {
    param(
        [scriptblock]$Job,
        [string]$Message
    )
    $spinner = @('|', '/', '-', '\\')
    $i = 0
    
    # Execute the job directly instead of using Start-Job for better compatibility
    $output = & $Job
    $exitCode = $LASTEXITCODE
    
    # Show completion message
    Write-Host "`r$Message ...done.   "
    
    return $output
}

# Function to run terraform command with progress
function Invoke-TerraformWithProgress {
    param(
        [string]$Command,
        [string]$Arguments,
        [string]$Activity,
        [string]$SuccessMessage,
        [string]$ErrorMessage
    )
    
    Write-Status "$Activity..."
    
    # Capture output and errors
    $output = & terraform $Command $Arguments.Split(' ') 2>&1
    $exitCode = $LASTEXITCODE
    
    if ($exitCode -eq 0) {
        Write-Success $SuccessMessage
        return $true
    } else {
        Write-Error $ErrorMessage
        Write-Error "Command output: $output"
        return $false
    }
}

# Function to run terraform apply with spinner
function Invoke-TerraformApply {
    param(
        [string]$planFile,
        [string]$phase
    )
    Write-Status "Applying $phase changes..."
    $applyJob = {
        terraform apply -auto-approve "$planFile" -no-color 2>&1
    }
    $applyOutput = Show-Spinner -Job $applyJob -Message "Running terraform apply"
    if ($LASTEXITCODE -eq 0) {
        Write-Success "$phase deployment completed successfully!"
        return $true
    } else {
        Write-Error "$phase deployment failed!"
        Write-Error "Apply output: $applyOutput"
        return $false
    }
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

# Function to run preflight checks
function Invoke-PreflightChecks {
    param([string]$env)
    Write-Status "Running preflight checks for $env environment..."
    
    $preflightScript = Join-Path $ScriptDir "preflight.ps1"
    if (Test-Path $preflightScript) {
        & $preflightScript $env
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Preflight checks failed"
            exit 1
        }
    } else {
        Write-Error "Preflight script not found"
        exit 1
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

# Function to deploy Phase 1 (independent resources)
function Deploy-Phase1 {
    param(
        [string]$env,
        $force,
        $dryRun
    )
    
    Write-Status "Deploying Phase 1: Independent resources..."
    
    # Change to project root
    Push-Location $ProjectRoot
    
    try {
        # Get environment configuration for backend setup
        $envConfig = Get-EnvironmentConfig $env
        $bucketName = $envConfig.bucket_name
        
        # Create temporary directory for Phase 1 deployment
        $phase1Dir = Join-Path $ProjectRoot "temp-phase1"
        if (Test-Path $phase1Dir) {
            Remove-Item $phase1Dir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $phase1Dir | Out-Null
        
        Write-Status "Creating Phase 1 workspace with independent resources only..."
        
        # Copy only Phase 1 files to temporary directory
        Copy-Item "main-independent.tf" $phase1Dir
        Copy-Item "variables.tf" $phase1Dir
        Copy-Item "providers.tf" $phase1Dir
        Copy-Item "versions.tf" $phase1Dir
        Copy-Item "backend.tf" $phase1Dir
        Copy-Item "environments" $phase1Dir -Recurse
        Copy-Item "modules" $phase1Dir -Recurse
        
        # Change to Phase 1 directory
        Push-Location $phase1Dir
        
        try {
            # Check if terraform init is needed
            if (-not (Test-Path ".terraform")) {
                Write-Status "Initializing Terraform for Phase 1..."
                $initResult = & terraform init -backend-config="bucket=$bucketName" -backend-config="prefix=terraform/state" 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Error "Terraform init failed: $initResult"
                    exit 1
                }
            }
            
            # Validate Terraform configuration
            if (-not (Invoke-TerraformWithProgress -Command "validate" -Arguments "" -Activity "Validating Terraform Configuration" -SuccessMessage "Terraform configuration is valid" -ErrorMessage "Terraform validation failed")) {
                exit 1
            }
            
            # Format Terraform code
            Write-Status "Formatting Terraform code..."
            terraform fmt -recursive | Out-Null
            
            # Generate plan for Phase 1 - Only resources from main-independent.tf
            Write-Status "Generating Phase 1 plan (independent resources only)..."
            
            # Run terraform plan for Phase 1 (only main-independent.tf resources)
            Write-Host "`n[INFO] Running: terraform plan -var=`"environment=$env`" -out=`"tfplan-phase1`"`n" -ForegroundColor Cyan
            Write-Host "Current directory: $(Get-Location)" -ForegroundColor Yellow
            Write-Host "Files in Phase 1 directory: $(Get-ChildItem -Name)" -ForegroundColor Yellow
            
            # Force output to display by explicitly calling terraform and flushing output
            $planResult = & terraform plan -var="environment=$env" -out="tfplan-phase1" -detailed-exitcode 2>&1
            $planExitCode = $LASTEXITCODE
            
            # Display the plan output with proper formatting
            $planResult -split "`n" | ForEach-Object { Write-Host $_ }
            
            # With -detailed-exitcode, terraform plan returns:
            # 0 = no changes, 1 = errors, 2 = changes to apply
            if ($planExitCode -eq 0 -or $planExitCode -eq 2) {
                Write-Success "Phase 1 plan generated successfully"
                
                # Check if plan file exists
                if (Test-Path "tfplan-phase1") {
                    Write-Host "`n[INFO] Phase 1 plan file created: tfplan-phase1" -ForegroundColor Green
                } else {
                    Write-Error "Phase 1 plan file not found: tfplan-phase1"
                    return $false
                }
            } else {
                Write-Error "Phase 1 plan generation failed"
                return $false
            }
            
            if ($dryRun) {
                Write-Success "Phase 1 dry run completed. Review the plan above."
                return
            }
            
            # Confirm deployment (unless -Force is used)
            if (-not $force) {
                Write-Host ""
                Write-Warning "You are about to deploy Phase 1 to the $env environment."
                Write-Warning "This will create independent resources (Firestore database, etc.)."
                
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
            
            # Apply Phase 1 changes
            if (-not (Invoke-TerraformApply -planFile "tfplan-phase1" -phase "Phase 1")) {
                exit 1
            }
            
            # Clean up plan file
            if (Test-Path "tfplan-phase1") {
                Remove-Item "tfplan-phase1"
            }
        }
        finally {
            Pop-Location
        }
    }
    finally {
        Pop-Location
        
        # Clean up temporary directory with retry logic for locked files
        if (Test-Path $phase1Dir) {
            Write-Status "Cleaning up temporary Phase 1 directory..."
            
            # Try to clean up with retry logic
            $maxRetries = 3
            $retryCount = 0
            $cleanupSuccess = $false
            
            while (-not $cleanupSuccess -and $retryCount -lt $maxRetries) {
                try {
                    # Force garbage collection to release file handles
                    [System.GC]::Collect()
                    [System.GC]::WaitForPendingFinalizers()
                    
                    # Wait a moment for processes to release handles
                    Start-Sleep -Seconds 2
                    
                    # Try to remove the directory
                    Remove-Item $phase1Dir -Recurse -Force -ErrorAction Stop
                    $cleanupSuccess = $true
                    Write-Success "Temporary Phase 1 directory cleaned up successfully"
                }
                catch {
                    $retryCount++
                    Write-Warning "Cleanup attempt $retryCount failed. Retrying in 5 seconds..."
                    Write-Warning "Error: $($_.Exception.Message)"
                    
                    if ($retryCount -lt $maxRetries) {
                        Start-Sleep -Seconds 5
                    }
                }
            }
            
            if (-not $cleanupSuccess) {
                Write-Warning "Could not clean up temporary directory: $phase1Dir"
                Write-Warning "You may need to manually delete this directory later."
                Write-Warning "The deployment completed successfully despite the cleanup issue."
            }
        }
    }
}

# Function to deploy Phase 2 (dependent resources)
function Deploy-Phase2 {
    param(
        [string]$env,
        $force,
        $dryRun
    )
    
    Write-Status "Deploying Phase 2: Dependent resources..."
    
    # Change to project root
    Push-Location $ProjectRoot
    
    try {
        # Get environment configuration for backend setup
        $envConfig = Get-EnvironmentConfig $env
        $bucketName = $envConfig.bucket_name
        
        # Create temporary directory for Phase 2 deployment
        $phase2Dir = Join-Path $ProjectRoot "temp-phase2"
        if (Test-Path $phase2Dir) {
            Remove-Item $phase2Dir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $phase2Dir | Out-Null
        
        Write-Status "Creating Phase 2 workspace with dependent resources only..."
        
        # Copy only Phase 2 files to temporary directory
        Copy-Item "main-dependent.tf" $phase2Dir
        Copy-Item "variables.tf" $phase2Dir
        Copy-Item "providers.tf" $phase2Dir
        Copy-Item "versions.tf" $phase2Dir
        Copy-Item "backend.tf" $phase2Dir
        Copy-Item "environments" $phase2Dir -Recurse
        Copy-Item "modules" $phase2Dir -Recurse
        
        # Change to Phase 2 directory
        Push-Location $phase2Dir
        
        try {
            # Check if terraform init is needed
            if (-not (Test-Path ".terraform")) {
                Write-Status "Initializing Terraform for Phase 2..."
                $initResult = & terraform init -backend-config="bucket=$bucketName" -backend-config="prefix=terraform/state" 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Error "Terraform init failed: $initResult"
                    exit 1
                }
            }
            
            # Validate Terraform configuration
            if (-not (Invoke-TerraformWithProgress -Command "validate" -Arguments "" -Activity "Validating Terraform Configuration" -SuccessMessage "Terraform configuration is valid" -ErrorMessage "Terraform validation failed")) {
                exit 1
            }
            
            # Format Terraform code
            Write-Status "Formatting Terraform code..."
            terraform fmt -recursive | Out-Null
            
            # Generate plan for Phase 2 - Only resources from main-dependent.tf
            Write-Status "Generating Phase 2 plan (dependent resources only)..."
            
            # Run terraform plan for Phase 2 (only main-dependent.tf resources)
            Write-Host "`n[INFO] Running: terraform plan -var=`"environment=$env`" -out=`"tfplan-phase2`"`n" -ForegroundColor Cyan
            Write-Host "Current directory: $(Get-Location)" -ForegroundColor Yellow
            Write-Host "Files in Phase 2 directory: $(Get-ChildItem -Name)" -ForegroundColor Yellow
            
            # Force output to display by explicitly calling terraform and flushing output
            $planResult = & terraform plan -var="environment=$env" -out="tfplan-phase2" -detailed-exitcode 2>&1
            $planExitCode = $LASTEXITCODE
            
            # Display the plan output with proper formatting
            $planResult -split "`n" | ForEach-Object { Write-Host $_ }
            
            # With -detailed-exitcode, terraform plan returns:
            # 0 = no changes, 1 = errors, 2 = changes to apply
            if ($planExitCode -eq 0 -or $planExitCode -eq 2) {
                Write-Success "Phase 2 plan generated successfully"
                
                # Check if plan file exists
                if (Test-Path "tfplan-phase2") {
                    Write-Host "`n[INFO] Phase 2 plan file created: tfplan-phase2" -ForegroundColor Green
                } else {
                    Write-Error "Phase 2 plan file not found: tfplan-phase2"
                    return $false
                }
            } else {
                Write-Error "Phase 2 plan generation failed"
                return $false
            }
            
            if ($dryRun) {
                Write-Success "Phase 2 dry run completed. Review the plan above."
                return
            }
            
            # Confirm deployment (unless -Force is used)
            if (-not $force) {
                Write-Host ""
                Write-Warning "You are about to deploy Phase 2 to the $env environment."
                Write-Warning "This will create Firestore indexes and dependent resources."
                Write-Warning "Firestore indexes can take 15-45 minutes to create."
                
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
            
            # Apply Phase 2 changes
            Write-Warning "Firestore indexes can take 15-45 minutes to create."
            if (-not (Invoke-TerraformApply -planFile "tfplan-phase2" -phase "Phase 2")) {
                exit 1
            }
            
            # Clean up plan file
            if (Test-Path "tfplan-phase2") {
                Remove-Item "tfplan-phase2"
            }
        }
        finally {
            Pop-Location
        }
    }
    finally {
        Pop-Location
        
        # Clean up temporary directory with retry logic for locked files
        if (Test-Path $phase2Dir) {
            Write-Status "Cleaning up temporary Phase 2 directory..."
            
            # Try to clean up with retry logic
            $maxRetries = 3
            $retryCount = 0
            $cleanupSuccess = $false
            
            while (-not $cleanupSuccess -and $retryCount -lt $maxRetries) {
                try {
                    # Force garbage collection to release file handles
                    [System.GC]::Collect()
                    [System.GC]::WaitForPendingFinalizers()
                    
                    # Wait a moment for processes to release handles
                    Start-Sleep -Seconds 2
                    
                    # Try to remove the directory
                    Remove-Item $phase2Dir -Recurse -Force -ErrorAction Stop
                    $cleanupSuccess = $true
                    Write-Success "Temporary Phase 2 directory cleaned up successfully"
                }
                catch {
                    $retryCount++
                    Write-Warning "Cleanup attempt $retryCount failed. Retrying in 5 seconds..."
                    Write-Warning "Error: $($_.Exception.Message)"
                    
                    if ($retryCount -lt $maxRetries) {
                        Start-Sleep -Seconds 5
                    }
                }
            }
            
            if (-not $cleanupSuccess) {
                Write-Warning "Could not clean up temporary directory: $phase2Dir"
                Write-Warning "You may need to manually delete this directory later."
                Write-Warning "The deployment completed successfully despite the cleanup issue."
            }
        }
    }
}

# Main execution
Write-Status "Starting deployment to $Environment environment..."

# Run preflight checks
Invoke-PreflightChecks $Environment

# Backup current state
Backup-State $Environment

# Determine which phases to deploy
if ($Phase1 -and $Phase2) {
    Write-Error "Cannot specify both -Phase1 and -Phase2. Choose one or neither for full deployment."
    exit 1
}

if ($Phase1) {
    # Deploy only Phase 1
    Write-Status "Deploying Phase 1 only (independent resources from main-independent.tf)..."
    Deploy-Phase1 $Environment $Force $DryRun
    Write-Success "Phase 1 deployment to $Environment completed successfully!"
    exit 0
}

if ($Phase2) {
    # Deploy only Phase 2
    Write-Status "Deploying Phase 2 only (dependent resources from main-dependent.tf)..."
    Deploy-Phase2 $Environment $Force $DryRun
    Write-Success "Phase 2 deployment to $Environment completed successfully!"
    exit 0
}

# Default: Deploy both phases
Write-Status "Deploying both phases (default behavior)..."
Write-Status "Phase 1: Independent resources (main-independent.tf)"
Deploy-Phase1 $Environment $Force $DryRun

if ($DryRun) {
    Write-Status "Phase 1 dry run completed. To continue with Phase 2, run: $($MyInvocation.MyCommand.Name) $Environment -Phase2"
    exit 0
}

# Wait a bit between phases
Write-Status "Waiting 5 seconds between phases..."
Start-Sleep -Seconds 5

# Deploy Phase 2
Write-Status "Phase 2: Dependent resources (main-dependent.tf)"
Deploy-Phase2 $Environment $Force $DryRun

Write-Success "Full deployment to $Environment completed successfully!"

# Function to manually clean up temporary directories (can be called separately)
function Remove-TemporaryDirectories {
    Write-Status "Cleaning up any remaining temporary directories..."
    
    $tempDirs = @(
        (Join-Path $ProjectRoot "temp-phase1"),
        (Join-Path $ProjectRoot "temp-phase2")
    )
    
    foreach ($tempDir in $tempDirs) {
        if (Test-Path $tempDir) {
            Write-Status "Attempting to clean up: $tempDir"
            
            try {
                # Force garbage collection
                [System.GC]::Collect()
                [System.GC]::WaitForPendingFinalizers()
                
                # Wait for processes to release handles
                Start-Sleep -Seconds 3
                
                # Try to remove the directory
                Remove-Item $tempDir -Recurse -Force -ErrorAction Stop
                Write-Success "Successfully cleaned up: $tempDir"
            }
            catch {
                Write-Warning "Could not clean up $tempDir : $($_.Exception.Message)"
                Write-Warning "You may need to restart your terminal or manually delete this directory."
            }
        }
    }
}

# Uncomment the line below to automatically clean up temporary directories after deployment
# Remove-TemporaryDirectories 