# Deployment Scripts

This directory contains deployment scripts for the Terraform infrastructure.

## Scripts Overview

### Unified Deployment Scripts

- **`deploy.ps1`** - Unified PowerShell script for Windows
- **`deploy.sh`** - Unified Bash script for macOS/Linux

### Legacy Scripts (Deprecated)

The `windows/` and `unix/` directories contain legacy individual environment scripts that have been replaced by the unified scripts.

## Usage

### Windows PowerShell

```powershell
# Deploy to development
.\scripts\deploy.ps1 -Environment dev

# Deploy to staging
.\scripts\deploy.ps1 -Environment staging

# Deploy to production
.\scripts\deploy.ps1 -Environment prod
```

### macOS/Linux

```bash
# Make script executable (first time only)
chmod +x scripts/deploy.sh

# Deploy to development
./scripts/deploy.sh dev

# Deploy to staging
./scripts/deploy.sh staging

# Deploy to production
./scripts/deploy.sh prod
```

## What the Scripts Do

1. **Set GCP Project** - Automatically sets the correct Google Cloud project for the environment
2. **Configure Backend** - Copies the appropriate backend configuration file
3. **Initialize Terraform** - Runs `terraform init` with the correct backend
4. **Validate Configuration** - Runs `terraform validate` to check for errors
5. **Plan Deployment** - Runs `terraform plan` with environment-specific variables
6. **Apply Changes** - Runs `terraform apply` to deploy the infrastructure

## Environment Configuration

The scripts automatically use the correct configuration files from the `config/` directory:

- **Development**: `config/backend-dev.tf` and `config/dev.tfvars`
- **Staging**: `config/backend-staging.tf` and `config/staging.tfvars`
- **Production**: `config/backend-prod.tf` and `config/prod.tfvars`

## Error Handling

- Scripts validate the environment argument before proceeding
- Clear error messages for invalid environments
- Color-coded output for different environments
- Automatic project switching for each environment 