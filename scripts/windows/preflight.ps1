# Preflight Check Script (PowerShell) - Simplified
# Usage: .\scripts\windows\preflight.ps1 [dev|staging|prod]

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment
)

# Script configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

# Simple preflight check that prints warnings and crashes on errors
Write-Host "Running preflight checks for $Environment environment..." -ForegroundColor Blue

# Check dependencies
$missingDeps = @()
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) { $missingDeps += "terraform" }
if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) { $missingDeps += "gcloud" }

if ($missingDeps.Count -gt 0) {
    Write-Host "[ERROR] Missing required dependencies: $($missingDeps -join ', ')" -ForegroundColor Red
    exit 1
}

# Check gcloud auth
$activeAccount = gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>$null
if (-not $activeAccount) {
    Write-Host "[ERROR] No active Google Cloud authentication found. Run 'gcloud auth login'" -ForegroundColor Red
    exit 1
}

# Check environment config
$envConfigFile = Join-Path $ProjectRoot "environments\$Environment.json"
if (-not (Test-Path $envConfigFile)) {
    Write-Host "[ERROR] Environment configuration file not found: $envConfigFile" -ForegroundColor Red
    exit 1
}

# Check gcloud project matches environment
$envConfig = Get-Content $envConfigFile | ConvertFrom-Json
$expectedProject = $envConfig.project_id
$activeProject = $(gcloud config get-value project 2>$null).Trim()
if ($activeProject -ne $expectedProject) {
    Write-Host "[ERROR] Active gcloud project ($activeProject) does not match environment project_id ($expectedProject). Run: gcloud config set project $expectedProject" -ForegroundColor Red
    exit 1
}

# Check if terraform init is needed
if (-not (Test-Path (Join-Path $ProjectRoot ".terraform"))) {
    Write-Host "[WARNING] Terraform not initialized. Run 'terraform init' before deployment." -ForegroundColor Yellow
    exit 1
}

Write-Host "[SUCCESS] Preflight checks passed for $Environment environment" -ForegroundColor Green 