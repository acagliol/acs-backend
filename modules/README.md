# Terraform Modules Structure

This directory contains modularized Terraform configurations for different GCP services, organized to replace your AWS infrastructure with Google Cloud equivalents.

## Module Overview

### Core Modules

| Module | AWS Equivalent | Purpose | File |
|--------|----------------|---------|------|
| `firestore/` | DynamoDB | NoSQL database with collections and indexes | `modules/firestore/main.tf` |
| `cloud-functions/` | Lambda | Serverless functions for business logic | `modules/cloud-functions/main.tf` |
| `api-gateway/` | API Gateway | HTTP API for frontend integration | `modules/api-gateway/main.tf` |
| `cloud-storage/` | S3 | Object storage for files and data | `modules/cloud-storage/main.tf` |
| `pub-sub/` | SQS | Message queuing and event processing | `modules/pub-sub/main.tf` |
| `identity-platform/` | Cognito | User authentication and management | `modules/identity-platform/main.tf` |
| `cloud-kms/` | KMS | Encryption key management | `modules/cloud-kms/main.tf` |
| `monitoring/` | CloudWatch | Logging, monitoring, and alerting | `modules/monitoring/main.tf` |

## Module Structure

Each module follows this structure:

```
modules/
├── module-name/
│   ├── main.tf          # Main module configuration
│   ├── variables.tf     # Variable definitions (if separate)
│   ├── outputs.tf       # Output definitions (if separate)
│   └── templates/       # Template files (if needed)
│       └── template.tftpl
```

## Usage

### 1. Environment Configuration

Environment-specific JSON files are located in `environments/`:

```json
{
  "environment": "dev",
  "project_id": "acs-dev-464702",
  "project_name": "acs-dev",
  "region": "us-central1",
  "zone": "us-central1-c",
  "bucket_name": "tf-state-dev-2",
  "subnet_cidr": "10.0.1.0/24",
  "machine_type": "e2-micro",
  "disk_size": 20,
  
  "firestore": {
    "database_id": "db-dev",
    "location_id": "us-central1",
    "database_type": "FIRESTORE_NATIVE"
  },
  
  "cloud_functions": {
    "region": "us-central1",
    "functions": {}
  },
  
  "api_gateway": {
    "region": "us-central1",
    "api_config": {}
  },
  
  "cloud_storage": {
    "region": "us-central1",
    "buckets": {}
  },
  
  "pub_sub": {
    "region": "us-central1",
    "topics": {},
    "subscriptions": {}
  },
  
  "identity_platform": {
    "region": "us-central1",
    "identity_platform_config": {}
  },
  
  "cloud_kms": {
    "region": "us-central1",
    "keyrings": {}
  },
  
  "monitoring": {
    "region": "us-central1",
    "monitoring_config": {}
  }
}
```

### 2. Main Configuration

The modules are used in the main configuration files:

**Phase 1** (`main-independent.tf`): Independent resources
```hcl
# Load environment configuration
locals {
  environment = var.environment != null ? var.environment : "dev"
  env_config_file = file("${path.module}/environments/${local.environment}.json")
  env_config      = jsondecode(local.env_config_file)
}

# Firestore database creation (independent resource)
resource "google_firestore_database" "database" {
  name        = "db-dev"
  location_id = local.env_config.region
  type        = "FIRESTORE_NATIVE"
}
```

**Phase 2** (`main-dependent.tf`): Dependent resources using modules
```hcl
# Load environment configuration
locals {
  environment = var.environment != null ? var.environment : "dev"
  env_config_file = file("${path.module}/environments/${local.environment}.json")
  env_config      = jsondecode(local.env_config_file)
}

# Use modules
module "firestore" {
  source = "./modules/firestore"

  project_id    = local.env_config.project_id
  environment   = local.environment
  location_id   = local.env_config.region
  database_name = "db-dev"
}

module "cloud_functions" {
  source = "./modules/cloud-functions"

  project_id  = local.env_config.project_id
  environment = local.environment
  region      = local.env_config.region
  functions   = {}
}

module "api_gateway" {
  source = "./modules/api-gateway"

  project_id  = local.env_config.project_id
  environment = local.environment
  region      = local.env_config.region
  api_config  = {}
}

module "cloud_storage" {
  source = "./modules/cloud-storage"

  project_id  = local.env_config.project_id
  environment = local.environment
  region      = local.env_config.region
  buckets     = {}
}

module "pub_sub" {
  source = "./modules/pub-sub"

  project_id    = local.env_config.project_id
  environment   = local.environment
  region        = local.env_config.region
  topics        = {}
  subscriptions = {}
}

module "identity_platform" {
  source = "./modules/identity-platform"

  project_id               = local.env_config.project_id
  environment              = local.environment
  region                   = local.env_config.region
  identity_platform_config = {}
}

module "cloud_kms" {
  source = "./modules/cloud-kms"

  project_id  = local.env_config.project_id
  environment = local.environment
  region      = local.env_config.region
  keyrings    = {}
}

module "monitoring" {
  source = "./modules/monitoring"

  project_id        = local.env_config.project_id
  environment       = local.environment
  region            = local.env_config.region
  monitoring_config = {}
}
```

### 3. Deployment

Use the provided deployment scripts:

```bash
# Deploy to dev environment
python scripts/run deploy dev

# Deploy to staging environment
python scripts/run deploy staging

# Deploy to production environment
python scripts/run deploy prod
```

Or use Terraform directly:

```bash
# Set environment variable
export TF_VAR_environment="dev"

# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var="environment=dev"

# Apply changes
terraform apply -var="environment=dev"
```

## Module Details

### Firestore Module

**Purpose**: NoSQL database (DynamoDB equivalent)

**Key Features**:
- Database creation with configurable location and type
- Collection creation with field definitions
- Index management for query optimization

**Configuration**:
```json
{
  "firestore": {
    "database_id": "db-dev",
    "location_id": "us-central1",
    "database_type": "FIRESTORE_NATIVE"
  }
}
```

**Module Usage**:
```hcl
module "firestore" {
  source = "./modules/firestore"

  project_id    = local.env_config.project_id
  environment   = local.environment
  location_id   = local.env_config.region
  database_name = "db-dev"
}
```

### Cloud Functions Module

**Purpose**: Serverless functions (Lambda equivalent)

**Key Features**:
- Multiple function support with different runtimes
- HTTP and Pub/Sub triggers
- Environment variables and memory configuration
- Source code packaging and deployment

**Configuration**:
```json
{
  "cloud_functions": {
    "region": "us-central1",
    "functions": {
      "email_processor": {
        "name": "email-processor",
        "runtime": "nodejs18",
        "entry_point": "processEmail",
        "source_dir": "../functions/email-processor",
        "trigger_type": "pubsub",
        "memory_mb": 512,
        "timeout_seconds": 300
      }
    }
  }
}
```

**Module Usage**:
```hcl
module "cloud_functions" {
  source = "./modules/cloud-functions"

  project_id  = local.env_config.project_id
  environment = local.environment
  region      = local.env_config.region
  functions   = local.env_config.cloud_functions.functions
}
```

### API Gateway Module

**Purpose**: HTTP API management (API Gateway equivalent)

**Key Features**:
- OpenAPI specification generation
- Endpoint routing to Cloud Functions
- CORS configuration
- Authentication integration

**Configuration**:
```json
{
  "api_gateway": {
    "region": "us-central1",
    "api_config": {
      "api_id": "company-api",
      "display_name": "Company API",
      "endpoints": {
        "get_users": {
          "name": "Get Users",
          "path": "/users",
          "method": "GET",
          "function": "get-users-function"
        }
      }
    }
  }
}
```

**Module Usage**:
```hcl
module "api_gateway" {
  source = "./modules/api-gateway"

  project_id  = local.env_config.project_id
  environment = local.environment
  region      = local.env_config.region
  api_config  = local.env_config.api_gateway.api_config
}
```

### Cloud Storage Module

**Purpose**: Object storage (S3 equivalent)

**Key Features**:
- Bucket creation with lifecycle policies
- CORS configuration
- IAM bindings and access control
- Versioning support

**Configuration**:
```json
{
  "cloud_storage": {
    "region": "us-central1",
    "buckets": {
      "app-storage": {
        "name": "app-storage-bucket",
        "location": "us-central1",
        "storage_class": "STANDARD",
        "versioning": true,
        "lifecycle_rules": [
          {
            "action": "Delete",
            "condition": {
              "age": 365
            }
          }
        ]
      }
    }
  }
}
```

**Module Usage**:
```hcl
module "cloud_storage" {
  source = "./modules/cloud-storage"

  project_id  = local.env_config.project_id
  environment = local.environment
  region      = local.env_config.region
  buckets     = local.env_config.cloud_storage.buckets
}
```

### Pub/Sub Module

**Purpose**: Message queuing (SQS equivalent)

**Key Features**:
- Topic and subscription management
- Dead letter queues
- Push and pull subscriptions
- IAM access control

**Configuration**:
```json
{
  "pub_sub": {
    "region": "us-central1",
    "topics": {
      "email-notifications": {
        "name": "email-notifications",
        "message_retention_duration": "604800s"
      }
    },
    "subscriptions": {
      "email-processor": {
        "name": "email-processor-sub",
        "topic": "email-notifications",
        "ack_deadline_seconds": 20
      }
    }
  }
}
```

**Module Usage**:
```hcl
module "pub_sub" {
  source = "./modules/pub-sub"

  project_id    = local.env_config.project_id
  environment   = local.environment
  region        = local.env_config.region
  topics        = local.env_config.pub_sub.topics
  subscriptions = local.env_config.pub_sub.subscriptions
}
```

### Identity Platform Module

**Purpose**: User authentication (Cognito equivalent)

**Key Features**:
- Multi-provider authentication
- User management
- Social login integration
- Custom claims and security policies

**Configuration**:
```json
{
  "identity_platform": {
    "region": "us-central1",
    "identity_platform_config": {
      "display_name": "Company Identity Platform",
      "enabled_sign_in_methods": ["EMAIL_PASSWORD", "GOOGLE"],
      "password_policy": {
        "min_length": 8,
        "require_uppercase": true,
        "require_lowercase": true,
        "require_numbers": true
      }
    }
  }
}
```

**Module Usage**:
```hcl
module "identity_platform" {
  source = "./modules/identity-platform"

  project_id               = local.env_config.project_id
  environment              = local.environment
  region                   = local.env_config.region
  identity_platform_config = local.env_config.identity_platform.identity_platform_config
}
```

### Cloud KMS Module

**Purpose**: Encryption key management (KMS equivalent)

**Key Features**:
- Keyring and key creation
- Key rotation policies
- Protection levels (software/hardware)
- IAM bindings for key access

**Configuration**:
```json
{
  "cloud_kms": {
    "region": "us-central1",
    "keyrings": {
      "app-keys": {
        "name": "app-encryption-keys",
        "location": "us-central1",
        "keys": {
          "data-encryption": {
            "name": "data-encryption-key",
            "purpose": "ENCRYPT_DECRYPT",
            "protection_level": "SOFTWARE"
          }
        }
      }
    }
  }
}
```

**Module Usage**:
```hcl
module "cloud_kms" {
  source = "./modules/cloud-kms"

  project_id  = local.env_config.project_id
  environment = local.environment
  region      = local.env_config.region
  keyrings    = local.env_config.cloud_kms.keyrings
}
```

### Monitoring Module

**Purpose**: Logging and monitoring (CloudWatch equivalent)

**Key Features**:
- Centralized logging with log sinks
- Uptime monitoring and alerting
- Performance metrics collection
- Notification channels

**Configuration**:
```json
{
  "monitoring": {
    "region": "us-central1",
    "monitoring_config": {
      "uptime_checks": {
        "api-health": {
          "name": "API Health Check",
          "uri": "https://api.example.com/health",
          "check_interval": "60s"
        }
      },
      "alert_policies": {
        "error-rate": {
          "name": "High Error Rate",
          "condition": "error_rate > 0.05",
          "notification_channels": ["email-alerts"]
        }
      }
    }
  }
}
```

**Module Usage**:
```hcl
module "monitoring" {
  source = "./modules/monitoring"

  project_id        = local.env_config.project_id
  environment       = local.environment
  region            = local.env_config.region
  monitoring_config = local.env_config.monitoring.monitoring_config
}
```

## Environment-Specific Configurations

### Development Environment
- **Project**: `acs-dev-464702`
- **Machine Type**: `e2-micro`
- **Disk Size**: 20GB
- **Features**: Basic monitoring, open access

### Staging Environment
- **Project**: `acs-staging-464702`
- **Machine Type**: `e2-small`
- **Disk Size**: 50GB
- **Features**: Production-like configuration

### Production Environment
- **Project**: `acs-prod-464702`
- **Machine Type**: `e2-standard-2`
- **Disk Size**: 100GB
- **Features**: Full monitoring, restricted access

## Best Practices

### Module Design
1. **Single Responsibility**: Each module handles one service type
2. **Reusability**: Modules can be used across environments
3. **Configuration**: Use variables for environment-specific settings
4. **Documentation**: Include clear documentation for each module

### Security
1. **Least Privilege**: Use minimal required permissions
2. **Environment Isolation**: Separate configurations per environment
3. **Encryption**: Enable encryption for all sensitive data
4. **Access Control**: Implement proper IAM policies

### Deployment
1. **Phase 1 First**: Deploy independent resources before dependent ones
2. **Environment Testing**: Test in dev before staging/prod
3. **Validation**: Always validate configurations before deployment
4. **Rollback**: Have rollback procedures ready

## Troubleshooting

### Common Issues

1. **Module Not Found**
   ```bash
   # Ensure module path is correct
   ls modules/firestore/main.tf
   ```

2. **Configuration Errors**
   ```bash
   # Validate configuration
   python scripts/run validate dev
   ```

3. **Permission Errors**
   ```bash
   # Check GCP project and authentication
   gcloud config get-value project
   gcloud auth list
   ```

4. **State Conflicts**
   ```bash
   # Check state and resolve conflicts
   terraform state list
   terraform state show <resource>
   ```

## Contributing

1. **Follow Module Structure**: Use the established module pattern
2. **Update Documentation**: Keep module documentation current
3. **Test Thoroughly**: Test modules in development first
4. **Version Control**: Commit changes with clear messages 