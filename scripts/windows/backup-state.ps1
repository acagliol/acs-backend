# State Backup Script (PowerShell) - Simplified
# Usage: .\scripts\windows\backup-state.ps1 [dev|staging|prod]

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment
)

# Script configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

# Simple backup that creates timestamped backup with logged user
Write-Host "Creating backup for $Environment environment..." -ForegroundColor Blue

# Create backup directory with timestamp and user
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$currentUser = $env:USERNAME
$backupDir = Join-Path $ProjectRoot "backups\$Environment\$timestamp-$currentUser"

if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
}

# Backup local state files
Push-Location $ProjectRoot
try {
    if (Test-Path "terraform.tfstate") {
        Copy-Item "terraform.tfstate" (Join-Path $backupDir "terraform.tfstate.backup.$timestamp")
    }
    if (Test-Path "terraform.tfstate.backup") {
        Copy-Item "terraform.tfstate.backup" (Join-Path $backupDir "terraform.tfstate.backup.$timestamp.backup")
    }
    
    # Create backup manifest
    $manifest = @{
        timestamp = $timestamp
        user = $currentUser
        environment = $Environment
        files = @()
    }
    
    if (Test-Path "terraform.tfstate") { $manifest.files += "terraform.tfstate" }
    if (Test-Path "terraform.tfstate.backup") { $manifest.files += "terraform.tfstate.backup" }
    
    $manifest | ConvertTo-Json | Out-File (Join-Path $backupDir "backup_manifest.$timestamp.json")
    
    Write-Host "[SUCCESS] Backup created at: $backupDir" -ForegroundColor Green
}
finally {
    Pop-Location
} 