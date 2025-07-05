# Terraform Infrastructure Deployment

Simple, cross-platform scripts for deploying Terraform infrastructure to dev, staging, and production environments.

## 🚀 Quick Start (Any Platform)

### 1. First Time Setup
```bash
# Set up your development environment
python scripts/run setup-env dev

# Set your Google Cloud project
gcloud config set project terraform-anay-dev
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
gcloud config set project terraform-anay-staging  # or terraform-anay-prod

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
gcloud config set project terraform-anay-dev

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
├── config/
│   └── environments.json      # Environment configurations
├── main.tf                    # Main Terraform configuration
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

# Set your project (replace with your project ID)
gcloud config set project terraform-anay-dev
```

## 🔧 Environment Configuration

The project supports three environments with different configurations:

| Environment | Project ID | Machine Type | Purpose |
|-------------|------------|--------------|---------|
| `dev` | `terraform-anay-dev` | `e2-micro` | Development & testing |
| `staging` | `terraform-anay-staging` | `e2-small` | Pre-production testing |
| `prod` | `terraform-anay-prod` | `e2-standard-2` | Production |

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
gcloud config set project terraform-anay-dev      # for dev
gcloud config set project terraform-anay-staging  # for staging
gcloud config set project terraform-anay-prod     # for prod
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
# Bucket names: terraform-state-dev-anay, terraform-state-staging-anay, terraform-state-prod-anay
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
1. ✅ **Set correct GCP project**: `gcloud config set project terraform-anay-[env]`
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

### Environment Configuration (`config/environments.json`)
```json
{
  "environments": {
    "dev": {
      "project_id": "terraform-anay-dev",
      "bucket_name": "terraform-state-dev-anay",
      "region": "us-central1",
      "zone": "us-central1-c",
      "machine_type": "e2-micro",
      "subnet_cidr": "10.0.1.0/24",
      "disk_size": 20
    }
  }
}
```

### Backend Configuration
- **State Storage**: Google Cloud Storage buckets
- **State Location**: `gs://terraform-state-[env]-anay/terraform/state`
- **Locking**: Automatic state locking via GCS

---

**Need help?** Check the troubleshooting section above or contact your infrastructure team. 