# Terraform Infrastructure Deployment

Simple, cross-platform scripts for deploying Terraform infrastructure to dev, staging, and production environments.

## 🚀 Quick Start (Any Platform)

### 1. First Time Setup
```bash
# Set up your development environment
python scripts/run setup-env dev

# Set your Google Cloud project
gcloud config set project acs-dev-464702
```

### 2. Deploy to Development
```bash
# Validate your configuration
python scripts/run validate dev

# Deploy (with safety checks)
python scripts/run deploy dev
```

### 3. Deploy to Staging/Production
```bash
# Set the correct project
gcloud config set project acs-staging-464702  # or acs-prod-464702

# Validate and deploy
python scripts/run validate staging
python scripts/run deploy staging
```

## 📋 Available Commands

All commands work on **Windows**, **macOS**, and **Linux** using the Python wrapper:

```bash
python scripts/run <command> [environment] [options]
```

### Core Commands

| Command | Description | Example |
|---------|-------------|---------|
| `setup-env` | Initialize a new environment | `python scripts/run setup-env dev` |
| `validate` | Check configuration for errors | `python scripts/run validate dev` |
| `deploy` | Deploy infrastructure | `python scripts/run deploy dev` |
| `rollback` | Emergency rollback | `python scripts/run rollback dev` |
| `backup-state` | Create state backup | `python scripts/run backup-state dev` |

### Command Options

- `--dry-run`: Show what would be deployed (deploy command only)
- `--force`: Skip confirmation prompts
- `--help`: Show detailed help

## 🔄 Typical Workflow

### Development Workflow
```bash
# 1. Set up environment (first time only)
python scripts/run setup-env dev
gcloud config set project acs-dev-464702

# 2. Make changes to Terraform files
# Edit main-independent.tf, main-dependent.tf, variables.tf, etc.

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

## 🛡️ Safety Features

- **Automatic state backups** before deployments
- **Production confirmation** - requires typing "PRODUCTION" for prod deployments
- **Project validation** - ensures you're deploying to the correct GCP project
- **Preflight checks** - validates dependencies and configuration
- **Rollback capability** - emergency rollback if needed

## 📁 Project Structure

```
terraform-anay-test/
├── scripts/
│   ├── run                    # Cross-platform Python wrapper
│   ├── mac/                   # macOS/Linux scripts
│   ├── windows/               # Windows PowerShell scripts
│   └── utils/                 # Configuration utilities
├── environments/              # Environment-specific configurations
│   ├── dev.json              # Development environment settings
│   ├── staging.json          # Staging environment settings
│   └── prod.json             # Production environment settings
├── main-independent.tf        # Phase 1: Independent resources
├── main-dependent.tf          # Phase 2: Dependent resources
├── variables.tf               # Variable definitions
├── backend.tf                 # Backend configuration
└── versions.tf                # Provider versions
```

## ⚙️ Prerequisites

### Required Tools
- **Terraform** (v1.0 or later)
- **Google Cloud SDK** (gcloud)
- **Python 3** (for cross-platform wrapper)

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

# Set your project (replace with your project name)
gcloud config set project acs-dev
```

## 🔧 Environment Configuration

The project supports three environments with different configurations:

| Environment | Project Name | Project ID | Machine Type | Purpose |
|-------------|--------------|------------|--------------|---------|
| `dev` | `acs-dev` | `acs-dev-464702` | `e2-micro` | Development & testing |
| `staging` | `acs-staging` | `acs-staging-464702` | `e2-small` | Pre-production testing |
| `prod` | `acs-prod` | `acs-prod-464702` | `e2-standard-2` | Production |

### Environment-Specific Settings

Each environment has its own:
- **GCP Project**: Isolated resources and billing
- **State Bucket**: Separate Terraform state storage
- **Resource Configuration**: Different machine types, regions, etc.

## 🚨 Troubleshooting

### Common Issues

#### "Active gcloud project does not match"
```bash
# Fix: Set the correct project for your environment
gcloud config set project acs-dev      # for dev
gcloud config set project acs-staging  # for staging
gcloud config set project acs-prod     # for prod
```

#### "Terraform validation failed"
```bash
# Fix: Run validation to see specific errors
python scripts/run validate dev

# Common fixes:
# - Check syntax in .tf files
# - Ensure all required variables are defined
# - Verify provider versions in versions.tf
```

#### "GCS bucket not found"
```bash
# Fix: Ensure the state bucket exists in your GCP project
# Bucket names: tf-state-dev, tf-state-prod, tf-state-staging
```

#### "Permission denied"
```bash
# Fix: Ensure you have the required GCP permissions
gcloud auth login
gcloud auth application-default login
```

### Emergency Procedures

#### Rollback Deployment
```bash
# Rollback to previous state
python scripts/run rollback dev

# Emergency rollback (skip confirmations)
python scripts/run rollback dev --force
```

#### Restore from Backup
```bash
# List available backups
ls backups/

# Restore from backup (manual process)
# 1. Copy backup files to project root
# 2. Run terraform init
# 3. Run terraform plan to verify
# 4. Run terraform apply if needed
```

## 📝 Best Practices

### Before Deployment
1. ✅ **Set correct GCP project**: `gcloud config set project acs-[env]`
2. ✅ **Validate configuration**: `python scripts/run validate [env]`
3. ✅ **Test with dry-run**: `python scripts/run deploy [env] --dry-run`
4. ✅ **Review the plan** carefully before applying

### Development
1. ✅ **Work on feature branches** - never deploy directly from main
2. ✅ **Commit frequently** - small, logical commits
3. ✅ **Test in dev first** - always validate in development before staging/prod
4. ✅ **Use environment variables** for sensitive data

### Security
1. ✅ **Never commit secrets** - use environment variables or secret management
2. ✅ **Review changes** - understand what resources will be created/modified
3. ✅ **Follow least privilege** - use minimal required permissions
4. ✅ **Backup before changes** - automatic backups are created, but verify

## 🤝 Getting Help

1. **Command help**: `python scripts/run [command] --help`
2. **Validation errors**: `python scripts/run validate [env]`
3. **Check logs**: Review the colored output for specific error messages
4. **Documentation**: Check the `docs/` directory for detailed guides

## 📄 Configuration Reference

### Environment Configuration (`environments/{env}.json`)
```json
{
  "environment": "dev",
  "project_id": "acs-dev-464702",
  "project_name": "acs-dev",
  "region": "us-central1",
  "zone": "us-central1-c",
  "firestore": {
    "database_id": "<name>",
    "location_id": "us-central1",
    "database_type": "FIRESTORE_NATIVE"
  },
  "cloud_functions": {
    "region": "us-central1",
    "functions": {}
  }
}
```

### Backend Configuration
- **State Storage**: Google Cloud Storage buckets
- **State Location**: `gs://tf-state-{environment}/terraform/state`
- **Locking**: Automatic state locking via GCS

---

**Need help?** Check the troubleshooting section above or contact your infrastructure team. 

# Deployment Scripts

This directory contains deployment scripts for different operating systems that handle Terraform deployments to various environments.

## Quick Start

### Using the main runner script (recommended)
```bash
# Deploy both phases to dev environment
python scripts/run deploy dev

# Deploy only Phase 1 to dev environment
python scripts/run deploy dev --phase1

# Deploy only Phase 2 to dev environment
python scripts/run deploy dev --phase2

# Dry run to see what would be deployed
python scripts/run deploy dev --dry-run

# Deploy to production (requires confirmation)
python scripts/run deploy prod --force
```

### Direct script usage

#### Windows (PowerShell)
```powershell
# Deploy both phases to dev environment
.\scripts\windows\deploy.ps1 dev

# Deploy only Phase 1 to dev environment
.\scripts\windows\deploy.ps1 dev -Phase1

# Deploy only Phase 2 to dev environment
.\scripts\windows\deploy.ps1 dev -Phase2

# Dry run to see what would be deployed
.\scripts\windows\deploy.ps1 dev -DryRun

# Deploy to production (requires confirmation)
.\scripts\windows\deploy.ps1 prod -Force
```

#### Linux/macOS
```bash
# Deploy both phases to dev environment
./scripts/linux/deploy.sh dev

# Deploy only Phase 1 to dev environment
./scripts/linux/deploy.sh dev --phase1

# Deploy only Phase 2 to dev environment
./scripts/linux/deploy.sh dev --phase2

# Dry run to see what would be deployed
./scripts/linux/deploy.sh dev --dry-run

# Deploy to production (requires confirmation)
./scripts/linux/deploy.sh prod --force
```

## Deployment Phases

The deployment is split into two phases to handle dependencies properly:

### Phase 1: Independent Resources (`main-independent.tf`)
- **Purpose**: Deploy foundational infrastructure that other resources depend on
- **Resources**: 
  - Google Cloud Project setup
  - VPC and networking
  - Firestore database
  - IAM roles and service accounts
  - Cloud Storage buckets
  - Cloud KMS keys
  - Basic monitoring setup

### Phase 2: Dependent Resources (`main-dependent.tf`)
- **Purpose**: Deploy resources that depend on Phase 1 infrastructure
- **Resources**:
  - Firestore indexes (can take 15-45 minutes)
  - Cloud Functions
  - API Gateway
  - Pub/Sub topics and subscriptions
  - Advanced monitoring and alerting
  - Identity Platform configuration

## Why Two Phases?

1. **Dependency Management**: Some resources (like Firestore indexes) depend on the database being created first
2. **Time Management**: Firestore indexes can take 15-45 minutes to create, so separating them allows for better progress tracking
3. **Error Isolation**: If Phase 2 fails, Phase 1 resources remain intact
4. **Rollback Capability**: Easier to rollback specific phases if needed

## Environment-Specific Behavior

### Development Environment
- **Access**: Full developer access
- **Confirmation**: Minimal prompts
- **Rollback**: Automated rollback available
- **Testing**: Ideal for testing new features

### Staging Environment
- **Access**: Developer access with approval
- **Confirmation**: Standard confirmation prompts
- **Rollback**: Automated rollback available
- **Testing**: Mirrors production configuration

### Production Environment
- **Access**: Admin access only
- **Confirmation**: Requires typing "PRODUCTION" to confirm
- **Rollback**: Manual rollback process
- **Protection**: Resources have `prevent_destroy` lifecycle rules

## Common Use Cases

### Initial Setup
```bash
# Deploy both phases to dev first
python scripts/run deploy dev

# Then deploy to staging
python scripts/run deploy staging

# Finally deploy to production (admin only)
python scripts/run deploy prod
```

### Adding New Features
```bash
# Test in dev first
python scripts/run deploy dev --phase1
python scripts/run deploy dev --phase2

# Then deploy to staging
python scripts/run deploy staging
```

### Infrastructure Updates
```bash
# Update only networking (Phase 1)
python scripts/run deploy dev --phase1

# Update only application resources (Phase 2)
python scripts/run deploy dev --phase2
```

### Troubleshooting
```bash
# See what would be deployed without making changes
python scripts/run deploy dev --dry-run

# Check specific phase
python scripts/run deploy dev --phase1 --dry-run
```

## Safety Features

### Pre-deployment Checks
- Validates environment configuration
- Checks gcloud project matches environment
- Verifies Terraform configuration
- Runs preflight checks

### State Management
- Automatic state backup before deployment
- Separate state files per environment
- State locking to prevent concurrent modifications

### Production Protection
- Requires explicit "PRODUCTION" confirmation
- Resources have `prevent_destroy` lifecycle rules
- Admin-only access to production
- Comprehensive audit logging

## Troubleshooting

### Common Issues

1. **"Terraform not initialized"**
   ```bash
   terraform init
   ```

2. **"Active gcloud project does not match"**
   ```bash
   gcloud config set project <project-id>
   ```

3. **"Environment configuration file not found"**
   - Check that `environments/<env>.json` exists
   - Verify the environment name is correct

4. **"Phase 2 fails after Phase 1"**
   - Check that Firestore database is ready
   - Verify all Phase 1 resources are properly created
   - Check for any dependency issues

### Getting Help

```bash
# Show usage information
python scripts/run deploy --help

# Show detailed help for specific environment
python scripts/run deploy dev --help
```

## Script Structure

```
scripts/
├── run                    # Main runner script (cross-platform)
├── windows/              # Windows-specific scripts
│   ├── deploy.ps1       # PowerShell deployment script
│   ├── preflight.ps1    # Pre-deployment checks
│   ├── backup-state.ps1 # State backup utility
│   └── rollback.ps1     # Rollback utility
├── linux/               # Linux-specific scripts
│   ├── deploy.sh        # Bash deployment script
│   ├── preflight.sh     # Pre-deployment checks
│   ├── backup-state.sh  # State backup utility
│   └── rollback.sh      # Rollback utility
└── mac/                 # macOS-specific scripts
    ├── deploy.sh        # Bash deployment script
    ├── preflight.sh     # Pre-deployment checks
    ├── backup-state.sh  # State backup utility
    └── rollback.sh      # Rollback utility
``` 