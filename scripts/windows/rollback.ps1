# Rollback Script (PowerShell)
# Usage: .\scripts\windows\rollback.ps1 [dev|staging|prod] [BACKUP_TIMESTAMP] [-Force] [-Help]

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,
    
    [Parameter(Mandatory=$false)]
    [string]$BackupTimestamp,
    
    [switch]$Force,
    [switch]$Help
)

# Script configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
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
Usage: $($MyInvocation.MyCommand.Name) [ENVIRONMENT] [BACKUP_TIMESTAMP] [OPTIONS]

ENVIRONMENTS:
    dev       - Rollback development environment
    staging   - Rollback staging environment
    prod      - Rollback production environment (admin only)

BACKUP_TIMESTAMP:
    Optional timestamp of backup to restore (format: yyyyMMdd_HHmmss)
    If not specified, will show available backups

OPTIONS:
    -Force     - Skip confirmation prompts
    -Help      - Show this help message

EXAMPLES:
    $($MyInvocation.MyCommand.Name) dev                                    # List available backups for dev
    $($MyInvocation.MyCommand.Name) staging 20241201_143022               # Rollback staging to specific backup
    $($MyInvocation.MyCommand.Name) prod 20241201_143022 -Force           # Rollback prod (skip confirmation)

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

# Function to check environment directory
function Test-EnvironmentDirectory {
    param([string]$env)
    $envDir = Join-Path $ProjectRoot "environments\$env"
    
    if (-not (Test-Path $envDir)) {
        Write-Error "Environment directory not found: $envDir"
        Write-Error "Run 'python scripts/run setup-env $env' to create the environment"
        return $false
    }
    
    return $true
}

# Function to check backup directory
function Test-BackupDirectory {
    param([string]$env)
    $backupDir = Join-Path $ProjectRoot "backups\$env"
    
    if (-not (Test-Path $backupDir)) {
        Write-Error "Backup directory not found: $backupDir"
        Write-Error "No backups available for $env environment"
        return $false
    }
    
    return $true
}

# Function to list available backups
function Get-AvailableBackups {
    param([string]$env)
    $backupDir = Join-Path $ProjectRoot "backups\$env"
    
    Write-Status "Available backups for $env environment:"
    Write-Host "=================================================="
    
    # Get all backup manifests
    $manifests = Get-ChildItem -Path $backupDir -Filter "backup_manifest.*.json" | Sort-Object LastWriteTime -Descending
    
    if ($manifests.Count -eq 0) {
        Write-Warning "No backup manifests found"
        return @()
    }
    
    $backups = @()
    
    foreach ($manifest in $manifests) {
        try {
            $manifestContent = Get-Content $manifest.FullName | ConvertFrom-Json
            $backupInfo = @{
                Timestamp = $manifestContent.timestamp
                Date = $manifestContent.backup_date
                Files = $manifestContent.backup_files
                TerraformVersion = $manifestContent.terraform_version
                ManifestFile = $manifest.FullName
            }
            $backups += $backupInfo
            
            Write-Host "Timestamp: $($backupInfo.Timestamp)"
            Write-Host "Date: $($backupInfo.Date)"
            Write-Host "Files: $($backupInfo.Files.Count)"
            Write-Host "Terraform Version: $($backupInfo.TerraformVersion)"
            Write-Host "---"
        } catch {
            Write-Warning "Failed to read manifest: $($manifest.Name)"
        }
    }
    
    return $backups
}

# Function to validate backup timestamp
function Test-BackupTimestamp {
    param(
        [string]$env,
        [string]$timestamp
    )
    $backupDir = Join-Path $ProjectRoot "backups\$env"
    $manifestFile = Join-Path $backupDir "backup_manifest.$timestamp.json"
    
    if (-not (Test-Path $manifestFile)) {
        Write-Error "Backup manifest not found for timestamp: $timestamp"
        return $false
    }
    
    try {
        $manifest = Get-Content $manifestFile | ConvertFrom-Json
        
        # Check if all backup files exist
        foreach ($file in $manifest.backup_files) {
            $filePath = Join-Path $backupDir $file
            if (-not (Test-Path $filePath)) {
                Write-Error "Backup file missing: $file"
                return $false
            }
        }
        
        Write-Success "Backup timestamp validated: $timestamp"
        return $true
    } catch {
        Write-Error "Failed to validate backup manifest"
        return $false
    }
}

# Function to backup current state before rollback
function Backup-CurrentState {
    param([string]$env)
    
    Write-Status "Creating backup of current state before rollback..."
    
    $backupScript = Join-Path $ScriptDir "backup-state.ps1"
    if (Test-Path $backupScript) {
        & $backupScript $env -Force
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Current state backed up successfully"
            return $true
        } else {
            Write-Warning "Failed to backup current state"
            return $false
        }
    } else {
        Write-Warning "Backup script not found, skipping current state backup"
        return $true
    }
}

# Function to restore local state
function Restore-LocalState {
    param(
        [string]$env,
        [string]$timestamp
    )
    $envDir = Join-Path $ProjectRoot "environments\$env"
    $backupDir = Join-Path $ProjectRoot "backups\$env"
    
    Write-Status "Restoring local state from backup..."
    
    Push-Location $envDir
    
    try {
        # Find the local state backup file
        $localBackupFile = Get-ChildItem -Path $backupDir -Filter "terraform.tfstate.backup.$timestamp" | Select-Object -First 1
        
        if (-not $localBackupFile) {
            Write-Warning "No local state backup found for timestamp: $timestamp"
            return $true
        }
        
        # Backup current state if it exists
        if (Test-Path "terraform.tfstate") {
            $currentBackup = "terraform.tfstate.rollback_backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Copy-Item "terraform.tfstate" $currentBackup
            Write-Status "Current state backed up to: $currentBackup"
        }
        
        # Restore from backup
        Copy-Item $localBackupFile.FullName "terraform.tfstate"
        Write-Success "Local state restored from: $($localBackupFile.Name)"
        
        return $true
    }
    finally {
        Pop-Location
    }
}

# Function to restore remote state
function Restore-RemoteState {
    param(
        [string]$env,
        [string]$timestamp
    )
    $envDir = Join-Path $ProjectRoot "environments\$env"
    $backupDir = Join-Path $ProjectRoot "backups\$env"
    
    Write-Status "Restoring remote state from backup..."
    
    Push-Location $envDir
    
    try {
        # Check if backend is configured
        if (-not (Test-Path "backend.tf")) {
            Write-Warning "No backend configuration found, skipping remote state restore"
            return $true
        }
        
        # Find the remote state backup file
        $remoteBackupFile = Get-ChildItem -Path $backupDir -Filter "remote_state_backup.$timestamp" | Select-Object -First 1
        
        if (-not $remoteBackupFile) {
            Write-Warning "No remote state backup found for timestamp: $timestamp"
            return $true
        }
        
        # Initialize Terraform if needed
        if (-not (Test-Path ".terraform")) {
            Write-Status "Initializing Terraform for remote state restore..."
            terraform init
        }
        
        # Push the backup state to remote
        if (terraform state push $remoteBackupFile.FullName) {
            Write-Success "Remote state restored from: $($remoteBackupFile.Name)"
            return $true
        } else {
            Write-Error "Failed to restore remote state"
            return $false
        }
    }
    finally {
        Pop-Location
    }
}

# Function to validate restored state
function Test-RestoredState {
    param([string]$env)
    $envDir = Join-Path $ProjectRoot "environments\$env"
    
    Write-Status "Validating restored state..."
    
    Push-Location $envDir
    
    try {
        # Validate Terraform configuration
        if (terraform validate) {
            Write-Success "Terraform configuration is valid"
        } else {
            Write-Error "Terraform configuration validation failed"
            return $false
        }
        
        # Show state summary
        $stateInfo = terraform show -json 2>$null | ConvertFrom-Json
        if ($stateInfo) {
            $resourceCount = $stateInfo.values.root_module.resources.Count
            Write-Status "Restored state contains $resourceCount resources"
        }
        
        # Show plan to see what would change
        Write-Status "Generating plan to check for differences..."
        $planResult = terraform plan -detailed-exitcode 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "No changes needed - state is in sync"
        } elseif ($LASTEXITCODE -eq 1) {
            Write-Warning "Plan failed - check the output above"
            return $false
        } elseif ($LASTEXITCODE -eq 2) {
            Write-Status "Plan shows changes - this is expected after rollback"
            Write-Status "Review the plan above to understand what will be applied"
        }
        
        return $true
    }
    finally {
        Pop-Location
    }
}

# Function to confirm rollback
function Confirm-Rollback {
    param(
        [string]$env,
        [string]$timestamp
    )
    
    Write-Host ""
    Write-Warning "You are about to rollback the $env environment to backup: $timestamp"
    Write-Warning "This will restore the infrastructure to a previous state"
    
    if ($env -eq "prod") {
        Write-Warning "⚠️  PRODUCTION ROLLBACK - This affects live systems!"
        Write-Host ""
        $confirmation = Read-Host "Type 'ROLLBACK' to confirm production rollback"
        if ($confirmation -ne "ROLLBACK") {
            Write-Error "Production rollback cancelled"
            return $false
        }
    } else {
        $confirmation = Read-Host "Do you want to continue with the rollback? (y/N)"
        if ($confirmation -notmatch "^[Yy]$") {
            Write-Error "Rollback cancelled"
            return $false
        }
    }
    
    return $true
}

# Function to perform rollback
function Invoke-Rollback {
    param(
        [string]$env,
        [string]$timestamp,
        [bool]$force
    )
    
    Write-Status "Starting rollback for $env environment..."
    Write-Host "=================================================="
    
    # Check environment directory
    if (-not (Test-EnvironmentDirectory $env)) {
        return $false
    }
    
    # Check backup directory
    if (-not (Test-BackupDirectory $env)) {
        return $false
    }
    
    # Validate backup timestamp
    if (-not (Test-BackupTimestamp $env $timestamp)) {
        return $false
    }
    
    # Confirm rollback (unless -Force is used)
    if (-not $force) {
        if (-not (Confirm-Rollback $env $timestamp)) {
            return $false
        }
    }
    
    # Backup current state before rollback
    if (-not (Backup-CurrentState $env)) {
        Write-Warning "Failed to backup current state, but continuing with rollback"
    }
    
    # Restore local state
    if (-not (Restore-LocalState $env $timestamp)) {
        Write-Error "Failed to restore local state"
        return $false
    }
    
    # Restore remote state
    if (-not (Restore-RemoteState $env $timestamp)) {
        Write-Warning "Failed to restore remote state"
    }
    
    # Validate restored state
    if (Test-RestoredState $env) {
        Write-Host "=================================================="
        Write-Success "Rollback completed successfully!"
        
        Write-Status "Next steps:"
        Write-Host "1. Review the infrastructure state"
        Write-Host "2. Run: python scripts/run validate $env"
        Write-Host "3. Run: python scripts/run deploy $env -DryRun"
        Write-Host "4. Run: python scripts/run deploy $env (if needed)"
        
        return $true
    } else {
        Write-Host "=================================================="
        Write-Error "Rollback validation failed"
        Write-Status "Please check the state manually and fix any issues"
        return $false
    }
}

# Function to handle interactive backup selection
function Select-Backup {
    param([string]$env)
    
    $backups = Get-AvailableBackups $env
    
    if ($backups.Count -eq 0) {
        Write-Error "No backups available for $env environment"
        return $null
    }
    
    Write-Host ""
    Write-Status "Select a backup to rollback to:"
    
    for ($i = 0; $i -lt $backups.Count; $i++) {
        $backup = $backups[$i]
        Write-Host "$($i + 1). $($backup.Timestamp) - $($backup.Date)"
    }
    
    do {
        $selection = Read-Host "Enter backup number (1-$($backups.Count)) or 'q' to quit"
        
        if ($selection -eq 'q') {
            Write-Error "Rollback cancelled"
            return $null
        }
        
        if ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $backups.Count) {
            $selectedBackup = $backups[[int]$selection - 1]
            return $selectedBackup.Timestamp
        } else {
            Write-Warning "Invalid selection. Please enter a number between 1 and $($backups.Count)"
        }
    } while ($true)
}

# Main execution
if ($Help) {
    Show-Usage
    exit 0
}

# Check dependencies
Test-Dependencies

# If no backup timestamp provided, show available backups and let user select
if (-not $BackupTimestamp) {
    $BackupTimestamp = Select-Backup $Environment
    if (-not $BackupTimestamp) {
        exit 1
    }
}

# Perform rollback
Invoke-Rollback $Environment $BackupTimestamp $Force 