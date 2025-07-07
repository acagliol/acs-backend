# Configuration Files

This directory contains all environment-specific configuration files for the Terraform infrastructure.

## File Structure

### Backend Configuration Files

These files define the Terraform state storage configuration for each environment:

- **`backend-dev.tf`** - Development environment backend configuration
- **`backend-staging.tf`** - Staging environment backend configuration  
- **`backend-prod.tf`** - Production environment backend configuration

Each backend file contains:
```hcl
terraform {
  backend "gcs" {
    bucket = "tf-state-{environment}-2"
    prefix = "terraform/state"
  }
}
```

### Variable Files

These files contain environment-specific variable values:

- **`dev.tfvars`** - Development environment variables
- **`staging.tfvars`** - Staging environment variables
- **`prod.tfvars`** - Production environment variables

Each `.tfvars` file contains:
```hcl
environment = "dev"      # or "staging" or "prod"
region      = "us-central1"
```

## Environment Mapping

| Environment | Backend Bucket | GCP Project | Variables File |
|-------------|----------------|-------------|----------------|
| `dev` | `tf-state-dev-2` | `acs-dev-464702` | `dev.tfvars` |
| `staging` | `tf-state-staging-2` | `acs-staging-464702` | `staging.tfvars` |
| `prod` | `tf-state-prod-2` | `acs-prod-464702` | `prod.tfvars` |

## Usage

### Manual Deployment

```bash
# Copy the appropriate backend configuration
cp config/backend-dev.tf backend.tf

# Initialize Terraform
terraform init

# Deploy with environment variables
terraform plan -var-file="config/dev.tfvars"
terraform apply -var-file="config/dev.tfvars"
```

### Using Deployment Scripts

The deployment scripts automatically use the correct configuration files:

```bash
# Windows PowerShell
.\scripts\deploy.ps1 -Environment dev

# macOS/Linux
./scripts/deploy.sh dev
```

## Configuration Management

- **Environment Isolation**: Each environment has separate state storage and configuration
- **Centralized Management**: All environment configurations are in one directory
- **Version Control**: All configuration files are tracked in version control
- **Easy Switching**: Simply change the environment parameter to switch configurations

## Security Considerations

- Backend buckets are environment-specific to prevent cross-environment contamination
- Production configurations should be reviewed before deployment
- All configurations are validated by Terraform before application 