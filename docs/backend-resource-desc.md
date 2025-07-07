# Backend Resource Descriptions for Terraform Infrastructure

## Overview

This document provides detailed descriptions of all backend resources in the Terraform infrastructure project, which uses a **2-step deployment approach** with files organized in the project root.

## Project Architecture

### 2-Step Deployment Structure
- **Phase 1** (`main-independent.tf`): Independent resources (Firestore database, basic infrastructure)
- **Phase 2** (`main-dependent.tf`): Dependent resources (modules, advanced configurations)
- **Root Files**: `versions.tf`, `providers.tf`, `variables.tf`, `backend.tf` in project root

### Environment Configuration
- **Environment JSON Files**: `environments/{env}.json` for environment-specific settings
- **Dynamic Loading**: Environment configurations loaded at runtime
- **Centralized Variables**: All variables defined in `variables.tf`

## Phase 1 Resources (Independent)

### Firestore Database

#### Resource: `google_firestore_database`
**File**: `main-independent.tf` (Phase 1)
**Purpose**: NoSQL document database for application data storage

**Configuration**:
```hcl
resource "google_firestore_database" "database" {
  name        = "db-dev"
  location_id = local.env_config.region
  type        = "FIRESTORE_NATIVE"
}
```

**Environment Configuration**:
```json
{
  "environment": "dev",
  "project_id": "acs-dev-464702",
  "region": "us-central1",
  "firestore": {
    "database_id": "db-dev",
    "location_id": "us-central1",
    "database_type": "FIRESTORE_NATIVE"
  }
}
```

**Features**:
- Document-based NoSQL database
- Automatic scaling
- Real-time updates
- Offline support
- Built-in security rules

**Use Cases**:
- User data storage
- Application state management
- Real-time collaboration
- Mobile app backend

### Environment Configuration Loading

#### Locals Block
**File**: `main-independent.tf` (Phase 1)
**Purpose**: Dynamic environment configuration loading

**Configuration**:
```hcl
locals {
  # Get environment from variable or default to dev
  environment = var.environment != null ? var.environment : "dev"

  # Load environment-specific configuration
  env_config_file = file("${path.module}/environments/${local.environment}.json")
  env_config      = jsondecode(local.env_config_file)

  # Common tags for all resources
  common_tags = {
    Environment = local.environment
    Project     = local.env_config.project_id
    ManagedBy   = "terraform"
    Owner       = "infrastructure-team"
    CostCenter  = "engineering"
  }
}
```

**Features**:
- Dynamic environment selection
- JSON configuration loading
- Consistent resource tagging
- Environment-specific settings

## Phase 2 Resources (Dependent)

### Firestore Module

#### Module: `firestore`
**File**: `main-dependent.tf` (Phase 2)
**Source**: `./modules/firestore`
**Purpose**: Advanced Firestore configuration and management

**Configuration**:
```hcl
module "firestore" {
  source = "./modules/firestore"

  project_id    = local.env_config.project_id
  environment   = local.environment
  location_id   = local.env_config.region
  database_name = "db-dev"
}
```

**Environment Configuration**:
```json
{
  "firestore": {
    "database_id": "db-dev",
    "location_id": "us-central1",
    "database_type": "FIRESTORE_NATIVE"
  }
}
```

**Features**:
- Advanced database configuration
- Collection and index management
- Security rules configuration
- Backup and restore capabilities

### Cloud Functions Module

#### Module: `cloud_functions`
**File**: `main-dependent.tf` (Phase 2)
**Source**: `./modules/cloud-functions`
**Purpose**: Serverless function deployment and management

**Configuration**:
```hcl
module "cloud_functions" {
  source = "./modules/cloud-functions"

  project_id  = local.env_config.project_id
  environment = local.environment
  region      = local.env_config.region
  functions   = {}
}
```

**Environment Configuration**:
```json
{
  "cloud_functions": {
    "region": "us-central1",
    "functions": {}
  }
}
```

**Features**:
- Serverless function deployment
- Multiple runtime support
- HTTP and Pub/Sub triggers
- Environment variable management
- Memory and timeout configuration

### API Gateway Module

#### Module: `api_gateway`
**File**: `main-dependent.tf` (Phase 2)
**Source**: `./modules/api-gateway`
**Purpose**: HTTP API management and routing

**Configuration**:
```hcl
module "api_gateway" {
  source = "./modules/api-gateway"

  project_id  = local.env_config.project_id
  environment = local.environment
  region      = local.env_config.region
  api_config  = {}
}
```

**Environment Configuration**:
```json
{
  "api_gateway": {
    "region": "us-central1",
    "api_config": {}
  }
}
```

**Features**:
- HTTP API management
- OpenAPI specification support
- Endpoint routing to Cloud Functions
- CORS configuration
- Authentication integration

### Cloud Storage Module

#### Module: `cloud_storage`
**File**: `main-dependent.tf` (Phase 2)
**Source**: `./modules/cloud-storage`
**Purpose**: Object storage bucket management

**Configuration**:
```hcl
module "cloud_storage" {
  source = "./modules/cloud-storage"

  project_id  = local.env_config.project_id
  environment = local.environment
  region      = local.env_config.region
  buckets     = {}
}
```

**Environment Configuration**:
```json
{
  "cloud_storage": {
    "region": "us-central1",
    "buckets": {}
  }
}
```

**Features**:
- Object storage buckets
- Lifecycle management
- CORS configuration
- IAM bindings
- Versioning support

### Pub/Sub Module

#### Module: `pub_sub`
**File**: `main-dependent.tf` (Phase 2)
**Source**: `./modules/pub-sub`
**Purpose**: Message queuing and event-driven architecture

**Configuration**:
```hcl
module "pub_sub" {
  source = "./modules/pub-sub"

  project_id    = local.env_config.project_id
  environment   = local.environment
  region        = local.env_config.region
  topics        = {}
  subscriptions = {}
}
```

**Environment Configuration**:
```json
{
  "pub_sub": {
    "region": "us-central1",
    "topics": {},
    "subscriptions": {}
  }
}
```

**Features**:
- Asynchronous messaging
- Topic and subscription management
- Dead letter queues
- Push and pull subscriptions
- IAM access control

### Identity Platform Module

#### Module: `identity_platform`
**File**: `main-dependent.tf` (Phase 2)
**Source**: `./modules/identity-platform`
**Purpose**: User authentication and authorization

**Configuration**:
```hcl
module "identity_platform" {
  source = "./modules/identity-platform"

  project_id               = local.env_config.project_id
  environment              = local.environment
  region                   = local.env_config.region
  identity_platform_config = {}
}
```

**Environment Configuration**:
```json
{
  "identity_platform": {
    "region": "us-central1",
    "identity_platform_config": {}
  }
}
```

**Features**:
- User authentication
- Multiple provider support
- Password policies
- Email verification
- OAuth configuration

### Cloud KMS Module

#### Module: `cloud_kms`
**File**: `main-dependent.tf` (Phase 2)
**Source**: `./modules/cloud-kms`
**Purpose**: Encryption key management

**Configuration**:
```hcl
module "cloud_kms" {
  source = "./modules/cloud-kms"

  project_id  = local.env_config.project_id
  environment = local.environment
  region      = local.env_config.region
  keyrings    = {}
}
```

**Environment Configuration**:
```json
{
  "cloud_kms": {
    "region": "us-central1",
    "keyrings": {}
  }
}
```

**Features**:
- Encryption key management
- Key rotation policies
- Protection levels
- IAM bindings
- Audit logging

### Monitoring Module

#### Module: `monitoring`
**File**: `main-dependent.tf` (Phase 2)
**Source**: `./modules/monitoring`
**Purpose**: Logging and monitoring infrastructure

**Configuration**:
```hcl
module "monitoring" {
  source = "./modules/monitoring"

  project_id        = local.env_config.project_id
  environment       = local.environment
  region            = local.env_config.region
  monitoring_config = {}
}
```

**Environment Configuration**:
```json
{
  "monitoring": {
    "region": "us-central1",
    "monitoring_config": {}
  }
}
```

**Features**:
- Centralized logging
- Uptime monitoring
- Alert policies
- Notification channels
- Performance metrics

## Environment-Specific Configurations

### Development Environment (`environments/dev.json`)

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

**Characteristics**:
- Minimal resource configurations
- Single instances where applicable
- Basic monitoring
- Open access for development
- Cost-optimized settings

### Staging Environment (`environments/staging.json`)

```json
{
  "environment": "staging",
  "project_id": "acs-staging-464702",
  "project_name": "acs-staging",
  "region": "us-central1",
  "zone": "us-central1-c",
  "bucket_name": "tf-state-staging-2",
  "subnet_cidr": "10.0.2.0/24",
  "machine_type": "e2-small",
  "disk_size": 50,
  
  "firestore": {
    "database_id": "db-staging",
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

**Characteristics**:
- Production-like configurations
- Multiple instances for testing
- Full monitoring and alerting
- Controlled access
- Performance testing capabilities

### Production Environment (`environments/prod.json`)

```json
{
  "environment": "prod",
  "project_id": "acs-prod-464702",
  "project_name": "acs-prod",
  "region": "us-central1",
  "zone": "us-central1-c",
  "bucket_name": "tf-state-prod-2",
  "subnet_cidr": "10.0.3.0/24",
  "machine_type": "e2-standard-2",
  "disk_size": 100,
  
  "firestore": {
    "database_id": "db-prod",
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

**Characteristics**:
- Full-scale configurations
- High availability setups
- Comprehensive monitoring
- Restricted access with IP whitelisting
- Performance-optimized settings

## Variable Definitions

### Core Variables (`variables.tf`)

```hcl
variable "environment" {
  description = "Environment to deploy (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
  default     = null

  validation {
    condition     = var.project_id == null || can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be 6-30 characters long, contain only lowercase letters, numbers, and hyphens, and start with a letter."
  }
}

variable "region" {
  description = "Google Cloud region for resources"
  type        = string
  default     = "us-central1"

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]*$", var.region))
    error_message = "Region must be a valid Google Cloud region (e.g., us-central1, europe-west1)."
  }
}
```

## Output Definitions

### Phase 1 Outputs

```hcl
output "environment_config" {
  description = "Current environment configuration"
  value       = local.env_config
}

output "firestore_database" {
  description = "Firestore database information"
  value = {
    name        = google_firestore_database.database.name
    location_id = google_firestore_database.database.location_id
    type        = google_firestore_database.database.type
    project     = google_firestore_database.database.project
  }
}
```

## Security Considerations

### Environment Isolation
- **Separate GCP Projects**: Each environment has its own isolated project
- **State Management**: Separate state files per environment
- **Access Control**: Environment-specific service accounts and IAM roles
- **Network Isolation**: Separate VPC networks and subnets

### Production Protection
- **Lifecycle Rules**: Production resources have `prevent_destroy` rules
- **Access Restrictions**: Production access limited to admin users
- **Confirmation Required**: Production deployments require explicit confirmation
- **Audit Logging**: Comprehensive logging of all operations

### Data Protection
- **Encryption at Rest**: All data encrypted using Cloud KMS
- **Encryption in Transit**: TLS encryption for all communications
- **Access Logging**: Detailed access logs for security monitoring
- **Backup and Recovery**: Regular backups with recovery procedures

## Deployment Strategy

### Two-Phase Approach

1. **Phase 1 Deployment**:
   - Deploy independent resources first
   - Establish foundational infrastructure
   - Create basic networking and storage

2. **Phase 2 Deployment**:
   - Deploy dependent resources
   - Configure advanced features
   - Set up monitoring and security

### Environment Promotion

1. **Development**: Initial testing and development
2. **Staging**: Pre-production validation
3. **Production**: Live environment deployment

### Rollback Strategy

- **State Backups**: Automatic backups before deployments
- **Phase-Specific Rollback**: Rollback individual phases if needed
- **Emergency Procedures**: Quick rollback to previous stable state

## Monitoring and Observability

### Resource Monitoring
- **Cloud Monitoring**: Comprehensive resource monitoring
- **Logging**: Centralized logging with Cloud Logging
- **Alerting**: Automated alerting for critical issues
- **Performance Metrics**: Application and infrastructure performance tracking

### Cost Management
- **Resource Tagging**: Consistent tagging for cost allocation
- **Budget Alerts**: Automated budget monitoring and alerts
- **Cost Optimization**: Environment-specific resource sizing
- **Usage Tracking**: Detailed usage analytics and reporting

## Best Practices

### Code Organization
- **Modular Design**: Reusable modules for common patterns
- **Environment Separation**: Clear separation of environment configurations
- **Version Control**: All configurations in version control
- **Documentation**: Comprehensive documentation for all resources

### Security Practices
- **Principle of Least Privilege**: Minimal required permissions
- **Regular Audits**: Periodic security reviews and updates
- **Secret Management**: Secure handling of sensitive information
- **Compliance**: Adherence to security and compliance standards

### Operational Practices
- **Automated Testing**: Automated validation of configurations
- **Change Management**: Controlled deployment processes
- **Disaster Recovery**: Comprehensive backup and recovery procedures
- **Performance Optimization**: Continuous performance monitoring and optimization

