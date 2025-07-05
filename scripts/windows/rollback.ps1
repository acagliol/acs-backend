# Rollback Script (PowerShell) - Simplified
# Usage: .\scripts\windows\rollback.ps1 [dev|staging|prod] [BACKUP_TIMESTAMP]

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,
    
    [Parameter(Mandatory=$false)]
    [string]$BackupTimestamp
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

# Function to list available backups
function Get-AvailableBackups {
    param([string]$env)
    $backupDir = Join-Path $ProjectRoot "backups\$env"
    
    if (-not (Test-Path $backupDir)) {
        Write-Error "No backup directory found for $env environment"
        exit 1
    }
    
    Write-Status "Available backups for $env environment:"
    
    # Get all backup directories
    $backupDirs = Get-ChildItem -Path $backupDir -Directory | Sort-Object LastWriteTime -Descending
    
    if ($backupDirs.Count -eq 0) {
        Write-Warning "No backups found"
        exit 1
    }
    
    foreach ($backupDir in $backupDirs) {
        $manifestFile = Join-Path $backupDir.FullName "backup_manifest.*.json"
        $manifest = Get-ChildItem -Path $manifestFile -ErrorAction SilentlyContinue
        
        if ($manifest) {
            try {
                $manifestContent = Get-Content $manifest.FullName | ConvertFrom-Json
                Write-Host "  $($backupDir.Name) - $($manifestContent.timestamp)"
            } catch {
                Write-Host "  $($backupDir.Name) - (manifest error)"
            }
        } else {
            Write-Host "  $($backupDir.Name)"
        }
    }
}

# Function to restore from backup
function Restore-FromBackup {
    param(
        [string]$env,
        [string]$timestamp
    )
    
    $backupDir = Join-Path $ProjectRoot "backups\$env\$timestamp"
    
    if (-not (Test-Path $backupDir)) {
        Write-Error "Backup directory not found: $backupDir"
        exit 1
    }
    
    Write-Status "Restoring from backup: $timestamp"
    
    # Change to project root
    Push-Location $ProjectRoot
    
    try {
        # Find backup files
        $stateBackup = Get-ChildItem -Path $backupDir -Filter "terraform.tfstate.backup.*" | Select-Object -First 1
        $backupBackup = Get-ChildItem -Path $backupDir -Filter "terraform.tfstate.backup.*.backup" | Select-Object -First 1
        
        if ($stateBackup) {
            Copy-Item $stateBackup.FullName "terraform.tfstate"
            Write-Success "Restored terraform.tfstate from backup"
        }
        
        if ($backupBackup) {
            Copy-Item $backupBackup.FullName "terraform.tfstate.backup"
            Write-Success "Restored terraform.tfstate.backup from backup"
        }
        
        if (-not $stateBackup -and -not $backupBackup) {
            Write-Error "No state files found in backup"
            exit 1
        }
        
        Write-Success "Rollback completed successfully"
        Write-Status "Run 'terraform plan' to verify the restored state"
    }
    finally {
        Pop-Location
    }
}

# Main execution
if (-not $BackupTimestamp) {
    # List available backups
    Get-AvailableBackups $Environment
    Write-Host ""
    Write-Status "To restore from a backup, specify the timestamp:"
    Write-Host "  .\scripts\windows\rollback.ps1 $Environment TIMESTAMP"
} else {
    # Restore from specified backup
    Restore-FromBackup $Environment $BackupTimestamp
} 