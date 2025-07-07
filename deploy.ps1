# =============================================================================
# DEPLOYMENT WRAPPER SCRIPT
# =============================================================================
# This script is a wrapper for the main deployment script
# Usage: .\deploy.ps1 -Environment dev|staging|prod

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment
)

# Get the script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DeployScript = Join-Path $ScriptDir "scripts\deploy.ps1"

# Check if the main deployment script exists
if (-not (Test-Path $DeployScript)) {
    Write-Host "❌ Error: Main deployment script not found at $DeployScript" -ForegroundColor Red
    exit 1
}

# Run the main deployment script
Write-Host "📁 Running deployment script from: $DeployScript" -ForegroundColor Cyan
& $DeployScript -Environment $Environment

# Exit with the same code as the main script
exit $LASTEXITCODE 