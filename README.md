# Terraform Modular Infrastructure

A comprehensive Terraform infrastructure project that uses a modular approach to deploy AWS-equivalent services on Google Cloud Platform. The project supports multiple environments (dev, staging, prod) with environment-specific settings loaded from JSON files.

## Project Structure

```
terraform-anay-test/
├── main.tf                    # Main Terraform configuration with modules
├── backend.tf                 # Backend configuration template
├── deploy.ps1                 # PowerShell deployment script
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
├── scripts/                   # Additional deployment scripts
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

## Quick Start

### Prerequisites

1. **Terraform** (>= 1.0)
2. **Google Cloud SDK** configured with appropriate credentials
3. **PowerShell** (for Windows deployment scripts)
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

### Deployment

#### Using the Deployment Script (Recommended)

```powershell
# Validate configuration
.\deploy.ps1 -Environment dev -Action validate

# Format Terraform code
.\deploy.ps1 -Environment dev -Action fmt

# Plan deployment to dev environment
.\deploy.ps1 -Environment dev -Action plan

# Apply deployment to dev environment
.\deploy.ps1 -Environment dev -Action apply

# Plan deployment to staging environment
.\deploy.ps1 -Environment staging -Action plan

# Apply deployment to staging environment
.\deploy.ps1 -Environment staging -Action apply

# Plan deployment to production (with SSH IP restrictions)
.\deploy.ps1 -Environment prod -Action plan -AllowedSshIps "192.168.1.1","10.0.0.1"

# Apply deployment to production
.\deploy.ps1 -Environment prod -Action apply -AllowedSshIps "192.168.1.1","10.0.0.1"

# Destroy resources (be careful!)
.\deploy.ps1 -Environment dev -Action destroy
```

#### Manual Deployment

```bash
# Set environment variable
$env:TF_VAR_environment = "dev"

# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var="environment=dev"

# Apply deployment
terraform apply -var="environment=dev" -auto-approve
```

## Environment Configuration

Each environment has its own JSON configuration file in the `environments/` directory. The configuration includes settings for all modules:

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
- Conditional resource creation
- Lifecycle policies for storage optimization
- Monitoring for cost tracking

## Safety Features

### Production Protection
- Manual confirmation required for production deployments
- `prevent_destroy` lifecycle rules for production resources
- SSH access restricted to specific IP addresses
- Separate state management per environment

### Deployment Safety
- Plan review before apply
- Staging testing before production
- Rollback procedures available
- State backups and validation

## Configuration

### Adding New Environments

1. Create a new JSON file in `environments/` directory
2. Follow the existing configuration structure
3. Configure all required modules for the environment

### Modifying Environment Settings

Edit the appropriate JSON file in `environments/`:
- `dev.json` for development settings
- `staging.json` for staging settings
- `prod.json` for production settings

### Adding New Modules

1. Create a new module directory in `modules/`
2. Define variables, resources, and outputs
3. Add module call to `main.tf`
4. Update environment JSON files with configuration
5. Add outputs to main configuration

## Migration from AWS

### Migration Steps

1. **Inventory AWS Resources**: Document all existing resources
2. **Create GCP Project**: Set up project with appropriate IAM
3. **Configure Environment Files**: Create JSON configs for each environment
4. **Deploy Modules**: Start with core services (Firestore, Cloud Functions)
5. **Test Integration**: Verify services work together
6. **Migrate Data**: Transfer data from AWS to GCP
7. **Update Applications**: Modify code to use GCP services
8. **Cutover**: Switch traffic from AWS to GCP

### Service Migration Order

1. **Database**: Migrate DynamoDB to Firestore
2. **Storage**: Migrate S3 to Cloud Storage
3. **Functions**: Migrate Lambda to Cloud Functions
4. **API**: Migrate API Gateway
5. **Queues**: Migrate SQS to Pub/Sub
6. **Auth**: Migrate Cognito to Identity Platform
7. **Monitoring**: Migrate CloudWatch to Monitoring
8. **Encryption**: Migrate KMS to Cloud KMS

## Troubleshooting

### Common Issues

1. **Module not found**
   - Ensure module directory exists in `modules/`
   - Check module source path in `main.tf`

2. **Environment configuration not found**
   - Verify JSON file exists in `environments/` directory
   - Check JSON syntax and structure

3. **API not enabled**
   - Enable required APIs in GCP project
   - Check service account permissions

4. **Production deployment blocked**
   - Ensure you have admin permissions
   - Provide SSH IP addresses for production

### Getting Help

- Check the `modules/README.md` for detailed module documentation
- Review the AI editing guide in `docs/ai-editing-guide.md`
- Consult the Terraform backend plan in `docs/terraform-backend-plan.md`

## Contributing

1. Follow the AI editing guide in `docs/ai-editing-guide.md`
2. Test changes in development environment first
3. Get approval for staging and production changes
4. Update documentation as needed
5. Use the modular structure for new features

## License

This project is for internal use only. 