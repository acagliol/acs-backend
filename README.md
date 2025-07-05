# Terraform Modular Infrastructure

A comprehensive Terraform infrastructure project that uses a modular approach to deploy AWS-equivalent services on Google Cloud Platform. The project supports multiple environments (dev, staging, prod) with environment-specific settings loaded from JSON files.

## Project Structure

```
terraform-anay-test/
├── main.tf                    # Main Terraform configuration with modules
├── backend.tf                 # Backend configuration template
├── config/
│   └── environments.json      # Environment configurations
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
├── scripts/                   # Cross-platform deployment scripts
│   ├── run                   # Python wrapper for all platforms
│   ├── windows/              # Windows PowerShell scripts
│   ├── mac/                  # macOS shell scripts
│   └── linux/                # Linux shell scripts
├── backups/                   # State backups
└── docs/                     # Documentation
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
3. **Python 3** (for cross-platform script wrapper)
4. **GCP Project** with required APIs enabled

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
choco install terraform googlecloudsdk python

# Or download from official sites
# https://www.terraform.io/downloads
# https://cloud.google.com/sdk/docs/install
```

#### macOS
```bash
# Install via Homebrew
brew install terraform google-cloud-sdk python

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

# Install Python 3
sudo apt-get install python3 python3-pip
```

### Setup Google Cloud
```bash
# Authenticate with Google Cloud
gcloud auth login

# Set your project (replace with your project ID)
gcloud config set project <PROJECT>
```

## 📋 Deployment

### First Time Setup

```bash
# Set up your development environment
python scripts/run setup-env dev

# Set your Google Cloud project
gcloud config set project acs-dev
```

### Available Commands

All commands work on **Windows**, **macOS**, and **Linux** using the Python wrapper:

```bash
python scripts/run <command> [environment] [options]
```

#### Core Commands

| Command | Description | Example |
|---------|-------------|---------|
| `setup-env` | Initialize a new environment | `python scripts/run setup-env dev` |
| `validate` | Check configuration for errors | `python scripts/run validate dev` |
| `deploy` | Deploy infrastructure | `python scripts/run deploy dev` |
| `rollback` | Emergency rollback | `python scripts/run rollback dev` |
| `backup-state` | Create state backup | `python scripts/run backup-state dev` |

#### Command Options

- `--dry-run`: Show what would be deployed (deploy command only)
- `--force`: Skip confirmation prompts
- `--help`: Show detailed help

### Development Workflow

```bash
# 1. Set up environment (first time only)
python scripts/run setup-env dev
gcloud config set project acs-dev

# 2. Make changes to Terraform files
# Edit main.tf, variables.tf, etc.

# 3. Validate changes
python scripts/run validate dev

# 4. Deploy with dry-run first
python scripts/run deploy dev --dry-run

# 5. Deploy to development
python scripts/run deploy dev
```

### Staging/Production Deployment

```bash
# 1. Set correct project
gcloud config set project terraform-anay-staging  # or terraform-anay-prod

# 2. Validate configuration
python scripts/run validate staging

# 3. Deploy (requires confirmation for production)
python scripts/run deploy staging
```

### Manual Deployment (Alternative)

If you prefer to run Terraform commands directly:

```bash
# Set environment variable
$env:TF_VAR_environment = "dev"  # Windows
export TF_VAR_environment="dev"   # macOS/Linux

# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var="environment=dev"

# Apply deployment
terraform apply -var="environment=dev" -auto-approve
```

## 🔧 Environment Configuration

The project supports three environments with different configurations:

| Environment | Project ID | Machine Type | Purpose |
|-------------|------------|--------------|---------|
| `dev` | `acs-dev` | `e2-micro` | Development & testing |
| `staging` | `terraform-anay-staging` | `e2-small` | Pre-production testing |
| `prod` | `terraform-anay-prod` | `e2-standard-2` | Production |

### Environment-Specific Settings

Each environment has its own:
- **GCP Project**: Isolated resources and billing
- **State Bucket**: Separate Terraform state storage
- **Resource Configuration**: Different machine types, regions, etc.

### Development (`environments/dev.json`)
- Minimal resource configurations
- Single instances where applicable
- Basic monitoring
- Open access for development

### Staging (`environments/staging.json`)
- Production-like configurations
- Multiple instances for testing
- Full monitoring and alerting
- Controlled access

### Production (`environments/prod.json`)
- Full-scale configurations
- High availability setups
- Comprehensive monitoring
- Restricted access with IP whitelisting

## 🛡️ Safety Features

- **Automatic state backups** before deployments
- **Production confirmation** - requires typing "PRODUCTION" for prod deployments
- **Project validation** - ensures you're deploying to the correct GCP project
- **Preflight checks** - validates dependencies and configuration
- **Rollback capability** - emergency rollback if needed

## Module Overview

### Firestore Module
- NoSQL database with collections and indexes
- Configurable location and database type
- Field definitions and validation

### Cloud Functions Module
- Serverless functions with multiple runtimes
- HTTP and Pub/Sub triggers
- Environment variables and memory configuration
- Source code packaging and deployment

### API Gateway Module
- HTTP API management with OpenAPI specs
- Endpoint routing to Cloud Functions
- CORS configuration and authentication
- Service account management

### Cloud Storage Module
- Object storage buckets with lifecycle policies
- CORS configuration and versioning
- IAM bindings and access control

### Pub/Sub Module
- Message queuing with topics and subscriptions
- Dead letter queues and retry policies
- Push subscriptions and IAM management

### Identity Platform Module
- User authentication with multiple providers
- Password policies and email verification
- OAuth configuration and multi-tenancy

### Cloud KMS Module
- Encryption key management with keyrings
- Key rotation policies and protection levels
- IAM bindings for key access

### Monitoring Module
- Log sinks for centralized logging
- Uptime checks and alerting policies
- Notification channels and service accounts

## Features

### Modular Architecture
- Each service type is isolated in its own module
- Reusable modules across environments
- Easy to add new services or modify existing ones
- Clear separation of concerns

### Dynamic Resource Creation
- Resources created based on environment configuration
- Conditional creation for environment-specific features
- Configurable resource specifications per environment

### Security Features
- Production resources protected with `prevent_destroy`
- SSH access restricted to specific IPs in production
- Environment-specific firewall rules
- Separate state files per environment
- Cloud KMS integration for encryption

### Cost Optimization
- Environment-specific resource sizing
- Development environments use minimal resources
- Staging environments mirror production at reduced scale
- Production environments optimized for performance

## 🚨 Troubleshooting

### Common Issues

#### "Active gcloud project does not match"
```bash
# Fix: Set the correct project for your environment
gcloud config set project acs-dev              # for dev
gcloud config set project terraform-anay-staging  # for staging
gcloud config set project terraform-anay-prod     # for prod
```

#### "Terraform validation failed"
```bash
# Fix: Run validation to see specific errors
python scripts/run validate dev
```

#### "Missing required dependencies"
```bash
# Fix: Install missing tools
# Windows: choco install terraform googlecloudsdk python
# macOS: brew install terraform google-cloud-sdk python
# Linux: Follow installation instructions above
```

#### "No active Google Cloud authentication found"
```bash
# Fix: Authenticate with Google Cloud
gcloud auth login
```

### Emergency Rollback

If a deployment fails or causes issues:

```bash
# Rollback to previous state
python scripts/run rollback dev

# Or manually restore from backup
# Check backups/ directory for available backups
```

## Contributing

1. Make changes to Terraform configurations
2. Test in development environment first
3. Validate changes: `python scripts/run validate dev`
4. Deploy to staging for testing
5. Deploy to production after approval

## License

This project is licensed under the MIT License - see the LICENSE file for details. 