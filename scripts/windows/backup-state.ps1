# State Backup Script (PowerShell)
# Usage: .\scripts\windows\backup-state.ps1 [dev|staging|prod] [-Force] [-Help]

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
    dev       - Backup state for development environment
    staging   - Backup state for staging environment
    prod      - Backup state for production environment

OPTIONS:
    -Force     - Overwrite existing backup
    -Help      - Show this help message

EXAMPLES:
    $($MyInvocation.MyCommand.Name) dev              # Backup dev state
    $($MyInvocation.MyCommand.Name) staging -Force   # Backup staging state (overwrite)
    $($MyInvocation.MyCommand.Name) prod             # Backup prod state

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

# Function to check environment configuration
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
        
        Write-Success "Environment configuration validated"
        return $true
    } catch {
        Write-Error "Failed to parse configuration file: $($_.Exception.Message)"
        return $false
    }
}

# Function to create backup directory
function New-BackupDirectory {
    param([string]$env)
    $backupDir = Join-Path $ProjectRoot "backups\$env"
    
    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        Write-Status "Created backup directory: $backupDir"
    }
    
    return $backupDir
}

# Function to backup local state
function Backup-LocalState {
    param(
        [string]$env,
        [string]$backupDir
    )
    
    Write-Status "Backing up local state for $env environment..."
    
    Push-Location $ProjectRoot
    
    try {
        # Check if terraform.tfstate exists
        if (-not (Test-Path "terraform.tfstate")) {
            Write-Warning "No local state file found for $env"
            return $true
        }
        
        # Create timestamp for backup
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupFile = Join-Path $backupDir "terraform.tfstate.backup.$timestamp"
        
        # Copy state file
        Copy-Item "terraform.tfstate" $backupFile
        Write-Success "Local state backed up to: $backupFile"
        
        # Also backup terraform.tfstate.backup if it exists
        if (Test-Path "terraform.tfstate.backup") {
            $backupBackupFile = Join-Path $backupDir "terraform.tfstate.backup.$timestamp.backup"
            Copy-Item "terraform.tfstate.backup" $backupBackupFile
            Write-Success "State backup file backed up to: $backupBackupFile"
        }
        
        return $true
    }
    finally {
        Pop-Location
    }
}

# Function to backup remote state
function Backup-RemoteState {
    param(
        [string]$env,
        [string]$backupDir
    )
    
    Write-Status "Backing up remote state for $env environment..."
    
    Push-Location $ProjectRoot
    
    try {
        # Get environment configuration for backend setup
        $config = Get-Content $ConfigFile | ConvertFrom-Json
        $envConfig = $config.environments.$env
        $bucketName = $envConfig.bucket_name
        
        # Initialize Terraform with backend configuration
        if (-not (Test-Path ".terraform")) {
            Write-Status "Initializing Terraform for state backup..."
            $backendConfig = @(
                "-backend-config=bucket=$bucketName",
                "-backend-config=prefix=terraform/state"
            )
            terraform init @backendConfig
        }
        
        # Create timestamp for backup
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $remoteBackupFile = Join-Path $backupDir "remote_state_backup.$timestamp"
        
        # Pull current state from remote
        if (terraform state pull > $remoteBackupFile 2>$null) {
            Write-Success "Remote state backed up to: $remoteBackupFile"
            
            # Show state summary
            $stateInfo = terraform show -json $remoteBackupFile 2>$null | ConvertFrom-Json
            if ($stateInfo) {
                $resourceCount = $stateInfo.values.root_module.resources.Count
                Write-Status "Remote state contains $resourceCount resources"
            }
        } else {
            Write-Warning "Failed to pull remote state for $env"
            return $false
        }
        
        return $true
    }
    finally {
        Pop-Location
    }
}

# Function to create backup manifest
function New-BackupManifest {
    param(
        [string]$env,
        [string]$backupDir,
        [string]$timestamp
    )
    
    Write-Status "Creating backup manifest..."
    
    $manifestFile = Join-Path $backupDir "backup_manifest.$timestamp.json"
    
    $manifest = @{
        environment = $env
        timestamp = $timestamp
        backup_date = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        backup_files = @()
        terraform_version = ""
        gcloud_version = ""
        backup_notes = ""
    }
    
    # Get Terraform version
    try {
        $tfVersion = (terraform version -json | ConvertFrom-Json).terraform_version
        $manifest.terraform_version = $tfVersion
    } catch {
        $manifest.terraform_version = "unknown"
    }
    
    # Get gcloud version
    try {
        $gcloudVersion = gcloud version --format="value(google_cloud_sdk_version)" 2>$null
        $manifest.gcloud_version = $gcloudVersion
    } catch {
        $manifest.gcloud_version = "unknown"
    }
    
    # List backup files
    $backupFiles = Get-ChildItem -Path $backupDir -Filter "*$timestamp*" | ForEach-Object { $_.Name }
    $manifest.backup_files = $backupFiles
    
    # Save manifest
    $manifest | ConvertTo-Json -Depth 10 | Out-File -FilePath $manifestFile -Encoding UTF8
    Write-Success "Backup manifest created: $manifestFile"
    
    return $manifestFile
}

# Function to cleanup old backups
function Remove-OldBackups {
    param([string]$backupDir)
    
    Write-Status "Cleaning up old backups..."
    
    # Keep backups from the last 30 days
    $cutoffDate = (Get-Date).AddDays(-30)
    
    $oldBackups = Get-ChildItem -Path $backupDir -Filter "*.backup.*" | Where-Object {
        $_.LastWriteTime -lt $cutoffDate
    }
    
    if ($oldBackups.Count -gt 0) {
        Write-Status "Removing $($oldBackups.Count) old backup files..."
        $oldBackups | Remove-Item -Force
        Write-Success "Old backups cleaned up"
    } else {
        Write-Status "No old backups to clean up"
    }
}

# Function to verify backup integrity
function Test-BackupIntegrity {
    param(
        [string]$env,
        [string]$backupDir,
        [string]$timestamp
    )
    
    Write-Status "Verifying backup integrity..."
    
    $backupFiles = Get-ChildItem -Path $backupDir -Filter "*$timestamp*"
    $manifestFile = Join-Path $backupDir "backup_manifest.$timestamp.json"
    
    if (-not (Test-Path $manifestFile)) {
        Write-Error "Backup manifest not found"
        return $false
    }
    
    # Check if all expected files exist
    $manifest = Get-Content $manifestFile | ConvertFrom-Json
    $expectedFiles = $manifest.backup_files
    
    foreach ($file in $expectedFiles) {
        $filePath = Join-Path $backupDir $file
        if (-not (Test-Path $filePath)) {
            Write-Error "Backup file missing: $file"
            return $false
        }
    }
    
    Write-Success "Backup integrity verified"
    return $true
}

# Function to show backup summary
function Show-BackupSummary {
    param(
        [string]$env,
        [string]$backupDir,
        [string]$timestamp,
        [string]$manifestFile
    )
    
    Write-Host ""
    Write-Host "=================================================="
    Write-Host "BACKUP SUMMARY"
    Write-Host "=================================================="
    Write-Host "Environment: $env"
    Write-Host "Backup Directory: $backupDir"
    Write-Host "Timestamp: $timestamp"
    Write-Host "Manifest: $manifestFile"
    Write-Host "=================================================="
    
    # Show backup files
    $backupFiles = Get-ChildItem -Path $backupDir -Filter "*$timestamp*"
    Write-Host "Backup Files:"
    foreach ($file in $backupFiles) {
        $size = [math]::Round($file.Length / 1KB, 2)
        Write-Host "  - $($file.Name) ($size KB)"
    }
    
    Write-Host "=================================================="
    Write-Success "State backup completed successfully!"
}

# Function to backup state for environment
function Backup-EnvironmentState {
    param(
        [string]$env,
        [bool]$force
    )
    
    Write-Status "Starting state backup for $env environment..."
    Write-Host "=================================================="
    
    # Check environment configuration
    if (-not (Test-EnvironmentConfig $env)) {
        return $false
    }
    
    # Create backup directory
    $backupDir = New-BackupDirectory $env
    
    # Create timestamp
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    
    # Backup local state
    if (-not (Backup-LocalState $env $backupDir)) {
        Write-Error "Failed to backup local state"
        return $false
    }
    
    # Backup remote state
    if (-not (Backup-RemoteState $env $backupDir)) {
        Write-Warning "Failed to backup remote state"
    }
    
    # Create backup manifest
    $manifestFile = New-BackupManifest $env $backupDir $timestamp
    
    # Cleanup old backups
    Remove-OldBackups $backupDir
    
    # Verify backup integrity
    if (Test-BackupIntegrity $env $backupDir $timestamp) {
        Write-Host "=================================================="
        Show-BackupSummary $env $backupDir $timestamp $manifestFile
        return $true
    } else {
        Write-Host "=================================================="
        Write-Error "Backup integrity check failed"
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

# Backup state for environment
Backup-EnvironmentState $Environment $Force 