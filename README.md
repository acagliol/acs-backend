# Terraform Modular Infrastructure

A comprehensive Terraform infrastructure project that uses a modular approach to deploy AWS-equivalent services on Google Cloud Platform. The project supports multiple environments (dev, staging, prod) with environment-specific settings loaded from JSON files.

## Project Structure

```
terraform-anay-test/
├── main-independent.tf        # Phase 1: Independent resources (database, storage, networking)
├── main-dependent.tf          # Phase 2: Dependent resources (modules, functions, monitoring)
├── variables.tf               # Variable declarations
├── backend.tf                 # Backend configuration template
├── providers.tf               # Provider configuration
├── versions.tf                # Version constraints
├── config/                    # Environment configurations
│   ├── backend-dev.tf         # Development backend configuration
│   ├── backend-staging.tf     # Staging backend configuration
│   ├── backend-prod.tf        # Production backend configuration
│   ├── dev.tfvars             # Development environment variables
│   ├── staging.tfvars         # Staging environment variables
│   └── prod.tfvars            # Production environment variables
├── scripts/                   # Deployment scripts
│   ├── deploy.ps1             # Unified Windows deployment script
│   ├── deploy.sh              # Unified Unix deployment script
│   ├── windows/               # Windows-specific scripts (legacy)
│   └── unix/                  # Unix-specific scripts (legacy)
├── environments/              # Environment-specific configurations
│   ├── dev.json              # Development environment settings
│   ├── staging.json          # Staging environment settings
│   └── prod.json             # Production environment settings
├── modules/                   # Terraform modules
│   ├── firestore/            # DynamoDB equivalent (NoSQL database)
│   ├── cloud-functions/      # Lambda equivalent (serverless functions)
│   ├── api-gateway/          # API Gateway equivalent
│   ├── cloud-storage/        # S3 equivalent (object storage)
│   ├── pub-sub/              # SQS equivalent (message queuing)
│   ├── identity-platform/    # Cognito equivalent (authentication)
│   ├── cloud-kms/            # KMS equivalent (encryption)
│   └── monitoring/           # CloudWatch equivalent (logging/monitoring)
├── backups/                   # State backups
├── docs/                     # Documentation
├── old_lambdas/              # Legacy AWS Lambda functions (for reference)
└── old_resources/            # Legacy AWS resource documentation
```

## AWS to GCP Service Mapping

| AWS Service | GCP Equivalent | Module | Purpose |
|-------------|----------------|--------|---------|
| Lambda | Cloud Functions | `cloud-functions/` | Serverless business logic |
| DynamoDB | Firestore | `firestore/` | NoSQL database with collections |
| API Gateway | API Gateway | `api-gateway/` | HTTP API management |
| S3 | Cloud Storage | `cloud-storage/` | Object storage for files |
| SQS | Pub/Sub | `pub-sub/` | Message queuing and events |
| Cognito | Identity Platform | `identity-platform/` | User authentication |
| KMS | Cloud KMS | `cloud-kms/` | Encryption key management |
| CloudWatch | Monitoring | `monitoring/` | Logging and monitoring |

## 🚀 Quick Start

### Prerequisites

1. **Terraform** (>= 1.0)
2. **Google Cloud SDK** configured with appropriate credentials
3. **GCP Project** with required APIs enabled

### Required GCP APIs

Enable these APIs in your GCP project:
- Cloud Functions API
- Firestore API
- API Gateway API
- Cloud Storage API
- Pub/Sub API
- Identity Platform API
- Cloud KMS API
- Monitoring API
- Compute Engine API

### Installation

#### Windows
```powershell
# Install via Chocolatey
choco install terraform googlecloudsdk

# Or download from official sites
# https://www.terraform.io/downloads
# https://cloud.google.com/sdk/docs/install
```

#### macOS
```bash
# Install via Homebrew
brew install terraform google-cloud-sdk

# Or download from official sites
```

#### Linux (Ubuntu/Debian)
```bash
# Install Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# Install Google Cloud SDK
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
sudo apt-get update && sudo apt-get install google-cloud-sdk
```

### Setup Google Cloud
```bash
# Authenticate with Google Cloud
gcloud auth login

# Set your project (replace with your project ID)
gcloud config set project <PROJECT>
```

## 📋 Deployment

### Simple Deployment Commands

The easiest way to deploy is using the unified deployment scripts:

#### Windows PowerShell
```powershell
# Development
.\scripts\deploy.ps1 -Environment dev

# Staging
.\scripts\deploy.ps1 -Environment staging

# Production
.\scripts\deploy.ps1 -Environment prod
```

#### macOS/Linux
```bash
# Development
./scripts/deploy.sh dev

# Staging
./scripts/deploy.sh staging

# Production
./scripts/deploy.sh prod
```

### Manual Deployment (Alternative)

If you prefer to run Terraform commands manually:

### Standard Terraform Commands

All deployments use standard Terraform commands:

#### Core Commands

| Command | Description | Example |
|---------|-------------|---------|
| `terraform init` | Initialize Terraform | `terraform init` |
| `terraform validate` | Check configuration for errors | `terraform validate` |
| `terraform plan` | Show deployment plan | `terraform plan -var-file="dev.tfvars"` |
| `terraform apply` | Deploy infrastructure | `terraform apply -var-file="dev.tfvars"` |
| `terraform destroy` | Remove infrastructure | `terraform destroy -var-file="dev.tfvars"` |

### Development Workflow

```bash
# 1. Set up environment (first time only)
# Copy the development backend configuration
cp config/backend-dev.tf backend.tf

# 2. Make changes to Terraform files
# Edit main-independent.tf, main-dependent.tf, variables.tf, etc.

# 3. Initialize Terraform
terraform init

# 4. Validate changes
terraform validate

# 5. Plan deployment
terraform plan -var-file="config/dev.tfvars"

# 6. Deploy to development
terraform apply -var-file="config/dev.tfvars"
```

### Staging/Production Deployment

```bash
# 1. Copy the appropriate backend configuration
cp config/backend-staging.tf backend.tf  # or config/backend-prod.tf for production

# 2. Initialize Terraform
terraform init

# 3. Validate configuration
terraform validate

# 4. Plan deployment
terraform plan -var-file="config/staging.tfvars"  # or config/prod.tfvars

# 5. Deploy (requires confirmation for production)
terraform apply -var-file="config/staging.tfvars"  # or config/prod.tfvars
```

### Environment-Specific Configuration Files

Each environment has its own configuration files:

| Environment | Variables File | Backend File | Backend Bucket |
|-------------|----------------|--------------|----------------|
| `dev` | `config/dev.tfvars` | `config/backend-dev.tf` | `tf-state-dev-2` |
| `staging` | `config/staging.tfvars` | `config/backend-staging.tf` | `tf-state-staging-2` |
| `prod` | `config/prod.tfvars` | `config/backend-prod.tf` | `tf-state-prod-2` |

### Complete Deployment Examples

#### Development Environment
```bash
# Windows PowerShell
cp config/backend-dev.tf backend.tf
terraform init
terraform plan -var-file="config/dev.tfvars"
terraform apply -var-file="config/dev.tfvars"

# macOS/Linux
cp config/backend-dev.tf backend.tf
terraform init
terraform plan -var-file="config/dev.tfvars"
terraform apply -var-file="config/dev.tfvars"
```

#### Staging Environment
```bash
# Windows PowerShell
cp config/backend-staging.tf backend.tf
terraform init
terraform plan -var-file="config/staging.tfvars"
terraform apply -var-file="config/staging.tfvars"

# macOS/Linux
cp config/backend-staging.tf backend.tf
terraform init
terraform plan -var-file="config/staging.tfvars"
terraform apply -var-file="config/staging.tfvars"
```

#### Production Environment
```bash
# Windows PowerShell
cp config/backend-prod.tf backend.tf
terraform init
terraform plan -var-file="config/prod.tfvars"
terraform apply -var-file="config/prod.tfvars"

# macOS/Linux
cp config/backend-prod.tf backend.tf
terraform init
terraform plan -var-file="config/prod.tfvars"
terraform apply -var-file="config/prod.tfvars"
```

## 🔧 Environment Configuration

The project supports three environments with different configurations:

| Environment | Project Name | Project ID | Machine Type | Purpose |
|-------------|--------------|------------|--------------|---------|
| `dev` | `acs-dev` | `acs-dev-464702` | `e2-micro` | Development & testing |
| `staging` | `acs-staging` | `acs-staging-464702` | `e2-small` | Pre-production testing |
| `prod` | `acs-prod` | `acs-prod-464702` | `e2-standard-2` | Production |

### Environment-Specific Settings

Each environment has its own configuration files:

#### JSON Configuration Files (`environments/` directory)
- **`environments/dev.json`**: Development environment settings
- **`environments/staging.json`**: Staging environment settings  
- **`environments/prod.json`**: Production environment settings

These files contain:
- Project ID and region settings
- Resource specifications (machine types, disk sizes, etc.)
- Module-specific configurations
- Network configurations

#### Terraform Variable Files (`.tfvars` files)
- **`dev.tfvars`**: Development environment variables
- **`staging.tfvars`**: Staging environment variables
- **`prod.tfvars`**: Production environment variables

These files contain:
- Environment name
- Region settings
- Backend bucket and prefix configuration
- All variables needed for deployment

### Dynamic Environment Loading

The Terraform configuration dynamically loads environment-specific settings:

```hcl
locals {
  environment = var.environment != null ? var.environment : "dev"
  env_config_file = file("${path.module}/environments/${local.environment}.json")
  env_config      = jsondecode(local.env_config_file)
}
```

## 🏗️ Architecture Overview

### Two-Phase Deployment

The infrastructure is deployed in two phases:

1. **Phase 1** (`main-independent.tf`): Independent resources that don't depend on other resources
   - Firestore database creation
   - Basic infrastructure setup

2. **Phase 2** (`main-dependent.tf`): Dependent resources that require Phase 1 resources
   - All modular components (Cloud Functions, API Gateway, etc.)
   - Advanced configurations

### Modular Design

The project uses Terraform modules for each major service:

- **`modules/firestore/`**: NoSQL database configuration
- **`modules/cloud-functions/`**: Serverless function deployment
- **`modules/api-gateway/`**: API management and routing
- **`modules/cloud-storage/`**: Object storage buckets
- **`modules/pub-sub/`**: Message queuing and events
- **`modules/identity-platform/`**: User authentication
- **`modules/cloud-kms/`**: Encryption key management
- **`modules/monitoring/`**: Logging and monitoring

## 🛡️ Security Features

- **Environment isolation**: Separate GCP projects for each environment
- **State management**: Remote state storage in GCS with encryption
- **Access control**: Principle of least privilege with service accounts
- **Production protection**: Confirmation required for production deployments
- **State backups**: Automatic backups before deployments

## 📊 Monitoring and Observability

- **Resource monitoring**: Cloud Monitoring integration
- **Logging**: Centralized logging with Cloud Logging
- **Cost tracking**: Resource cost monitoring
- **Performance metrics**: Application performance monitoring

## 🚨 Troubleshooting

### Common Issues

#### "Active gcloud project does not match"
```bash
# Fix: Set the correct project for your environment
gcloud config set project acs-dev-464702      # for dev
gcloud config set project acs-staging-464702  # for staging
gcloud config set project acs-prod-464702     # for prod
```

#### "Environment configuration not found"
```bash
# Fix: Ensure the environment JSON file exists
ls environments/dev.json
ls environments/staging.json
ls environments/prod.json
```

#### "Terraform state locked"
```bash
# Fix: Force unlock state (use with caution)
terraform force-unlock <LOCK_ID>
```

#### "Backend configuration error"
```bash
# Fix: Reinitialize with correct backend configuration
terraform init -backend-config="bucket=tf-state-{environment}-2" -backend-config="prefix=terraform/state"
```

## 📚 Additional Documentation

- **`docs/backend-resource-desc.md`**: Detailed resource descriptions
- **`modules/README.md`**: Module-specific documentation

## 🤝 Contributing

1. Make changes in the development environment first
2. Test thoroughly in staging before production
3. Follow the established naming conventions
4. Update documentation for any changes
5. Use standard Terraform commands for deployment

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details. 