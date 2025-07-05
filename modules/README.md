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

Create environment-specific JSON files in `environments/`:

```json
{
  "environment": "dev",
  "project_id": "your-project-id",
  "region": "us-central1",
  
  "firestore": {
    "database_id": "(default)",
    "collections": {
      "users": {
        "name": "users",
        "fields": {
          "email": { "type": "string" },
          "name": { "type": "string" }
        }
      }
    }
  },
  
  "cloud_functions": {
    "functions": {
      "email_processor": {
        "name": "email-processor",
        "runtime": "nodejs18",
        "entry_point": "processEmail",
        "source_dir": "../functions/email-processor",
        "trigger_type": "pubsub"
      }
    }
  }
}
```

### 2. Main Configuration

Use the modular main configuration (`main-modular.tf`):

```hcl
# Load environment configuration
locals {
  environment = var.environment != null ? var.environment : "dev"
  env_config_file = file("${path.module}/environments/${local.environment}.json")
  env_config = jsondecode(local.env_config_file)
}

# Use modules
module "firestore" {
  source = "./modules/firestore"
  
  project_id   = local.env_config.project_id
  environment  = local.environment
  database_id  = local.env_config.firestore.database_id
  collections  = local.env_config.firestore.collections
}

module "cloud_functions" {
  source = "./modules/cloud-functions"
  
  project_id  = local.env_config.project_id
  environment = local.environment
  functions   = local.env_config.cloud_functions.functions
}
```

### 3. Deployment

```bash
# Deploy to dev environment
terraform plan -var="environment=dev"
terraform apply -var="environment=dev"

# Deploy to staging environment
terraform plan -var="environment=staging"
terraform apply -var="environment=staging"

# Deploy to production environment
terraform plan -var="environment=prod"
terraform apply -var="environment=prod"
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
    "database_id": "(default)",
    "location_id": "us-central1",
    "database_type": "FIRESTORE_NATIVE",
    "collections": {
      "users": {
        "name": "users",
        "fields": {
          "email": { "type": "string" },
          "created_at": { "type": "timestamp" }
        }
      }
    }
  }
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
    "api_config": {
      "api_id": "company-api",
      "display_name": "Company API",
      "endpoints": {
        "get_users": {
          "name": "Get Users",
          "path": "/users",
          "method": "GET",
          "function_name": "user-api",
          "auth_required": true
        }
      }
    }
  }
}
```

### Cloud Storage Module

**Purpose**: Object storage (S3 equivalent)

**Key Features**:
- Multiple bucket creation
- Lifecycle policies
- CORS configuration
- Versioning support

**Configuration**:
```json
{
  "cloud_storage": {
    "buckets": {
      "email_attachments": {
        "name": "email-attachments",
        "location": "US",
        "versioning": true,
        "lifecycle_rules": [
          {
            "action": { "type": "Delete" },
            "condition": { "age": 365 }
          }
        ]
      }
    }
  }
}
```

### Pub/Sub Module

**Purpose**: Message queuing (SQS equivalent)

**Key Features**:
- Topic and subscription management
- Dead letter queues
- Retry policies
- Push subscriptions

**Configuration**:
```json
{
  "pub_sub": {
    "topics": {
      "email_queue": {
        "name": "email-queue",
        "message_retention_duration": "604800s"
      }
    },
    "subscriptions": {
      "email_processor_sub": {
        "name": "email-processor-sub",
        "topic": "email_queue",
        "ack_deadline_seconds": 60
      }
    }
  }
}
```

### Identity Platform Module

**Purpose**: Authentication (Cognito equivalent)

**Key Features**:
- Multiple sign-in providers (Google, Facebook, Email)
- Password policies
- Email verification
- Multi-tenancy support

**Configuration**:
```json
{
  "identity_platform": {
    "identity_platform_config": {
      "display_name": "Company Auth",
      "sign_in_options": [
        {
          "provider": "email",
          "enabled": true
        },
        {
          "provider": "google",
          "enabled": true,
          "provider_config": {
            "client_id": "your-client-id",
            "client_secret": "your-client-secret"
          }
        }
      ]
    }
  }
}
```

### Cloud KMS Module

**Purpose**: Encryption key management (KMS equivalent)

**Key Features**:
- Keyring and crypto key creation
- Key rotation policies
- Different key purposes (encrypt/decrypt, sign/verify)

**Configuration**:
```json
{
  "cloud_kms": {
    "keyrings": {
      "app_keys": {
        "name": "app-keys",
        "keys": {
          "data_encryption": {
            "name": "data-encryption",
            "purpose": "ENCRYPT_DECRYPT",
            "rotation_period": "7776000s"
          }
        }
      }
    }
  }
}
```

### Monitoring Module

**Purpose**: Observability (CloudWatch equivalent)

**Key Features**:
- Log sinks for centralized logging
- Uptime checks
- Alerting policies
- Notification channels

**Configuration**:
```json
{
  "monitoring": {
    "monitoring_config": {
      "log_sinks": {
        "audit_logs": {
          "name": "audit-logs",
          "destination": "storage.googleapis.com/audit-logs-bucket",
          "filter": "resource.type=\"cloud_function\""
        }
      },
      "uptime_checks": {
        "api_health": {
          "display_name": "API Health Check",
          "http_check": {
            "path": "/health",
            "port": 443,
            "use_ssl": true
          }
        }
      }
    }
  }
}
```

## Best Practices

### 1. Environment Separation
- Use separate JSON files for each environment
- Keep sensitive data in environment variables or Secret Manager
- Use different project IDs for each environment

### 2. Security
- Enable uniform bucket-level access for Cloud Storage
- Use least-privilege IAM roles
- Enable Cloud KMS for encryption
- Restrict SSH access in production

### 3. Monitoring
- Set up log sinks for centralized logging
- Create uptime checks for critical services
- Configure alerting policies for errors and performance issues

### 4. Cost Optimization
- Use appropriate machine types and storage classes
- Set up lifecycle policies for data retention
- Monitor resource usage and costs

## Migration from AWS

### Service Mapping

| AWS Service | GCP Equivalent | Module |
|-------------|----------------|--------|
| Lambda | Cloud Functions | `cloud-functions/` |
| DynamoDB | Firestore | `firestore/` |
| API Gateway | API Gateway | `api-gateway/` |
| S3 | Cloud Storage | `cloud-storage/` |
| SQS | Pub/Sub | `pub-sub/` |
| Cognito | Identity Platform | `identity-platform/` |
| KMS | Cloud KMS | `cloud-kms/` |
| CloudWatch | Monitoring | `monitoring/` |

### Migration Steps

1. **Inventory AWS Resources**: Document all existing resources
2. **Create GCP Project**: Set up project with appropriate IAM
3. **Configure Environment Files**: Create JSON configs for each environment
4. **Deploy Modules**: Start with core services (Firestore, Cloud Functions)
5. **Test Integration**: Verify services work together
6. **Migrate Data**: Transfer data from AWS to GCP
7. **Update Applications**: Modify code to use GCP services
8. **Cutover**: Switch traffic from AWS to GCP

## Troubleshooting

### Common Issues

1. **Permission Errors**: Ensure service accounts have appropriate roles
2. **Resource Naming**: GCP has stricter naming requirements than AWS
3. **Region Availability**: Some services may not be available in all regions
4. **API Enablement**: Enable required APIs in your GCP project

### Useful Commands

```bash
# Validate configuration
terraform validate

# Format code
terraform fmt

# Plan changes
terraform plan -var="environment=dev"

# Apply changes
terraform apply -var="environment=dev"

# Destroy resources (be careful!)
terraform destroy -var="environment=dev"
```

## Next Steps

1. Review and customize the environment configurations
2. Set up your GCP project and enable required APIs
3. Create service account keys for authentication
4. Deploy the infrastructure incrementally
5. Test each module individually
6. Integrate with your application code
7. Set up monitoring and alerting
8. Plan the production migration 