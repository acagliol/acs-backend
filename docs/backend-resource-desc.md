# Backend Resource Descriptions for Terraform Infrastructure

## Overview

This document provides detailed descriptions of all backend resources in the Terraform infrastructure project, which uses a **2-step deployment approach** with files organized in the project root.

## Project Architecture

### 2-Step Deployment Structure
- **Phase 1** (`main-independent.tf`): Independent resources (APIs, service accounts, IAM)
- **Phase 2** (`main-dependent.tf`): Dependent resources (Firestore, modules, indexes)
- **Root Files**: `versions.tf`, `providers.tf`, `variables.tf`, `backend.tf` in project root

### Environment Configuration
- **Environment JSON Files**: `environments/{env}.json` for environment-specific settings
- **Dynamic Loading**: Environment configurations loaded at runtime
- **Centralized Variables**: All variables defined in `variables.tf`

## Phase 1 Resources (Independent)

### Google Cloud APIs

#### Resource: `google_project_service`
**File**: `main-independent.tf` (Phase 1)
**Purpose**: Enable required Google Cloud APIs for the project

**Configuration**:
```hcl
resource "google_project_service" "required_apis" {
  for_each = toset([
    "firestore.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "run.googleapis.com",
    "storage.googleapis.com",
    "pubsub.googleapis.com",
    "identitytoolkit.googleapis.com",
    "cloudkms.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com"
  ])

  project = local.env_config.project_id
  service = each.value
  disable_dependent_services = false
  disable_on_destroy         = false
}
```

**Features**:
- Enables all required APIs for the infrastructure
- Prevents accidental API disabling
- Ensures APIs are available for Phase 2 resources

### Terraform Service Account

#### Resource: `google_service_account` and `google_project_iam_member`
**File**: `main-independent.tf` (Phase 1)
**Purpose**: Service account for Terraform operations with appropriate permissions

**Configuration**:
```hcl
resource "google_service_account" "terraform_sa" {
  account_id   = "terraform-sa-${local.environment}"
  display_name = "Terraform Service Account for ${local.environment}"
  project      = local.env_config.project_id
}

resource "google_project_iam_member" "terraform_roles" {
  for_each = toset([
    "roles/firestore.admin",
    "roles/cloudfunctions.developer",
    "roles/storage.admin",
    "roles/pubsub.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/cloudkms.admin",
    "roles/monitoring.admin",
    "roles/logging.admin"
  ])

  project = local.env_config.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.terraform_sa.email}"
}
```

**Features**:
- Dedicated service account for Terraform operations
- Principle of least privilege with specific roles
- Environment-specific naming

## Phase 2 Resources (Dependent)

### Firestore Database

#### Resource: `google_firestore_database`
**File**: `main-dependent.tf` (Phase 2) via firestore module
**Purpose**: NoSQL document database for application data storage

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
    "database_id": "dev-database",
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

### Cloud Storage

#### Resource: `google_storage_bucket`
**File**: `main-dependent.tf` (Phase 2)
**Purpose**: Object storage for files, images, and static assets

**Configuration**:
```hcl
module "cloud_storage" {
  source = "./modules/cloud-storage"
  project_id  = local.env_config.project_id
  environment = local.environment
  region      = local.env_config.cloud_storage.region
  buckets     = local.env_config.cloud_storage.buckets
}
```

**Environment Configuration**:
```json
{
  "cloud_storage": {
    "region": "us-central1",
    "buckets": [
      {
        "name": "dev-storage-bucket",
        "location": "us-central1",
        "storage_class": "STANDARD"
      }
    ]
  }
}
```

**Features**:
- Object storage with global edge locations
- Multiple storage classes
- Lifecycle management
- Access control
- Versioning support

**Use Cases**:
- Static website hosting
- File uploads and downloads
- Backup storage
- Media file storage

### Pub/Sub Messaging

#### Resource: `google_pubsub_topic` and `google_pubsub_subscription`
**File**: `main-dependent.tf` (Phase 2)
**Purpose**: Asynchronous messaging and event-driven architecture

**Configuration**:
```hcl
module "pub_sub" {
  source = "./modules/pub-sub"
  project_id    = local.env_config.project_id
  environment   = local.environment
  region        = local.env_config.pub_sub.region
  topics        = local.env_config.pub_sub.topics
  subscriptions = local.env_config.pub_sub.subscriptions
}
```

**Environment Configuration**:
```json
{
  "pub_sub": {
    "region": "us-central1",
    "topics": [
      {
        "name": "dev-notifications",
        "message_retention_duration": "604800s"
      }
    ],
    "subscriptions": [
      {
        "name": "dev-notifications-sub",
        "topic": "dev-notifications",
        "ack_deadline_seconds": 20
      }
    ]
  }
}
```

**Features**:
- Asynchronous messaging
- Guaranteed delivery
- Automatic scaling
- Message ordering
- Dead letter queues

**Use Cases**:
- Event-driven architecture
- Microservices communication
- Background job processing
- Real-time notifications

## Networking Resources

### VPC Network

#### Resource: `google_compute_network`
**File**: `main-independent.tf` (Phase 1)
**Purpose**: Virtual private cloud for network isolation

**Configuration**:
```hcl
resource "google_compute_network" "vpc" {
  name                    = "vpc-${local.environment}"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  project                 = local.env_config.project_id
}
```

**Features**:
- Network isolation
- Custom routing
- Subnet management
- Firewall rules
- Load balancing

**Use Cases**:
- Application network isolation
- Multi-tier architecture
- Security segmentation
- Hybrid cloud connectivity

### Subnet

#### Resource: `google_compute_subnetwork`
**File**: `main-independent.tf` (Phase 1)
**Purpose**: IP address range within VPC

**Configuration**:
```hcl
resource "google_compute_subnetwork" "subnet" {
  name          = "subnet-${local.environment}"
  ip_cidr_range = "10.0.1.0/24"
  network       = google_compute_network.vpc.id
  region        = local.env_config.region
  project       = local.env_config.project_id
}
```

**Features**:
- IP address management
- Regional deployment
- Private Google access
- Flow logs

**Use Cases**:
- Resource placement
- Network segmentation
- IP address planning
- Regional deployments

### Firewall Rules

#### Resource: `google_compute_firewall`
**File**: `main-independent.tf` (Phase 1)
**Purpose**: Network security and access control

**Web Access Rule**:
```hcl
resource "google_compute_firewall" "allow_web" {
  name    = "allow-web-${local.environment}"
  network = google_compute_network.vpc.name
  project = local.env_config.project_id
  
  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
  
  source_ranges = local.environment == "prod" ? [] : ["0.0.0.0/0"]
  target_tags   = ["web"]
  description = "Allow HTTP/HTTPS traffic - restricted in production"
}
```

**SSH Access Rule**:
```hcl
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh-${local.environment}"
  network = google_compute_network.vpc.name
  project = local.env_config.project_id
  
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  
  source_ranges = local.environment == "prod" ? var.allowed_ssh_ips : ["0.0.0.0/0"]
  target_tags   = ["ssh"]
  description = "Allow SSH access - restricted to specific IPs in production"
}
```

**Features**:
- Port-based filtering
- Source IP restrictions
- Target tag filtering
- Environment-specific rules
- Security logging

**Use Cases**:
- Application security
- Administrative access
- Network segmentation
- Compliance requirements

## Module-Based Resources (Phase 2)

### Cloud Functions

#### Module: `cloud-functions`
**File**: `main-dependent.tf` (Phase 2)
**Purpose**: Serverless function execution

**Configuration**:
```hcl
module "cloud_functions" {
  source = "./modules/cloud-functions"
  project_id  = local.env_config.project_id
  environment = local.environment
  region      = local.env_config.cloud_functions.region
  functions   = local.env_config.cloud_functions.functions
}
```

**Environment Configuration**:
```json
{
  "cloud_functions": {
    "region": "us-central1",
    "functions": [
      {
        "name": "dev-api-handler",
        "runtime": "nodejs18",
        "entry_point": "handler",
        "source_dir": "functions/api-handler",
        "trigger_http": true
      }
    ]
  }
}
```

**Features**:
- Serverless execution
- Automatic scaling
- Multiple runtimes
- HTTP triggers
- Event-driven

**Use Cases**:
- API endpoints
- Data processing
- Event handlers
- Microservices

### API Gateway

#### Module: `api-gateway`
**File**: `main-dependent.tf` (Phase 2)
**Purpose**: HTTP API management and routing

**Configuration**:
```hcl
module "api_gateway" {
  source = "./modules/api-gateway"
  project_id  = local.env_config.project_id
  environment = local.environment
  region      = local.env_config.api_gateway.region
  api_config  = local.env_config.api_gateway.api_config
}
```

**Environment Configuration**:
```json
{
  "api_gateway": {
    "region": "us-central1",
    "api_config": {
      "api_id": "dev-api",
      "display_name": "Development API",
      "openapi_doc": "api-spec.yaml"
    }
  }
}
```

**Features**:
- HTTP API management
- OpenAPI specification
- Authentication
- Rate limiting
- Monitoring

**Use Cases**:
- REST API hosting
- API versioning
- Client SDK generation
- API documentation

### Identity Platform

#### Module: `identity-platform`
**File**: `main-dependent.tf` (Phase 2)
**Purpose**: User authentication and authorization

**Configuration**:
```hcl
module "identity_platform" {
  source = "./modules/identity-platform"
  project_id               = local.env_config.project_id
  environment              = local.environment
  region                   = local.env_config.identity_platform.region
  identity_platform_config = local.env_config.identity_platform.identity_platform_config
}
```

**Environment Configuration**:
```json
{
  "identity_platform": {
    "region": "us-central1",
    "identity_platform_config": {
      "display_name": "Development Identity Platform",
      "enabled_sign_in_methods": ["EMAIL_PASSWORD", "GOOGLE"]
    }
  }
}
```

**Features**:
- Multi-provider authentication
- User management
- Social login
- Custom claims
- Security policies

**Use Cases**:
- User authentication
- Single sign-on
- Social login integration
- User profile management

### Cloud KMS

#### Module: `cloud-kms`
**File**: `main-dependent.tf` (Phase 2)
**Purpose**: Encryption key management

**Configuration**:
```hcl
module "cloud_kms" {
  source = "./modules/cloud-kms"
  project_id  = local.env_config.project_id
  environment = local.environment
  region      = local.env_config.cloud_kms.region
  keyrings    = local.env_config.cloud_kms.keyrings
}
```

**Environment Configuration**:
```json
{
  "cloud_kms": {
    "region": "us-central1",
    "keyrings": [
      {
        "name": "dev-encryption-keys",
        "location": "us-central1"
      }
    ]
  }
}
```

**Features**:
- Encryption key management
- Hardware security modules
- Key rotation
- Audit logging
- Compliance support

**Use Cases**:
- Data encryption
- Secret management
- Compliance requirements
- Secure key storage

### Monitoring

#### Module: `monitoring`
**File**: `main-dependent.tf` (Phase 2)
**Purpose**: Infrastructure monitoring and alerting

**Configuration**:
```hcl
module "monitoring" {
  source = "./modules/monitoring"
  project_id        = local.env_config.project_id
  environment       = local.environment
  region            = local.env_config.monitoring.region
  monitoring_config = local.env_config.monitoring.monitoring_config
}
```

**Environment Configuration**:
```json
{
  "monitoring": {
    "region": "us-central1",
    "monitoring_config": {
      "uptime_checks": [
        {
          "name": "dev-api-uptime",
          "uri": "https://api.dev.example.com/health"
        }
      ],
      "alert_policies": [
        {
          "name": "dev-error-alerts",
          "condition": "error_rate > 0.05"
        }
      ]
    }
  }
}
```

**Features**:
- Uptime monitoring
- Performance metrics
- Alert policies
- Log analysis
- Dashboard creation

**Use Cases**:
- Service monitoring
- Performance tracking
- Incident response
- Capacity planning

## Stack Helper Files

### Variables (`stack/variables.tf`)
**Purpose**: Centralized variable definitions with validation

**Key Variables**:
- `environment`: Target environment (dev, staging, prod)
- `project_id`: Google Cloud Project ID
- `region`: Google Cloud region
- `allowed_ssh_ips`: SSH access control
- `allowed_web_ips`: Web access control
- `subnet_config`: Subnet configuration

### Outputs (`stack/outputs.tf`)
**Purpose**: Resource information and status outputs

**Key Outputs**:
- Firestore database information
- VPC and subnet details
- Module outputs
- Connection information
- Status indicators

### Providers (`stack/providers.tf`)
**Purpose**: Google Cloud provider configurations

**Providers**:
- Google provider for standard resources
- Google-beta provider for beta features
- Archive provider for function deployments

### Versions (`stack/versions.tf`)
**Purpose**: Version constraints for Terraform and providers

**Constraints**:
- Terraform version requirements
- Provider version constraints
- Compatibility specifications

### Backend (`stack/backend.tf`)
**Purpose**: Remote state storage configuration

**Configuration**:
- GCS backend for state storage
- Environment-specific buckets
- State locking and encryption

## Environment-Specific Configurations

### Development Environment
- **Project**: `terraform-anay-dev`
- **Region**: `us-central1`
- **Features**: Basic monitoring, open access
- **Resources**: Minimal for cost efficiency

### Staging Environment
- **Project**: `terraform-anay-staging`
- **Region**: `us-central1`
- **Features**: Production-like configuration
- **Resources**: Full feature set for testing

### Production Environment
- **Project**: `terraform-anay-prod`
- **Region**: `us-central1`
- **Features**: Full monitoring, restricted access
- **Resources**: High availability, security focus

## Resource Dependencies

### Phase 1 Dependencies
- **Firestore Database**: No dependencies
- **Cloud Storage**: No dependencies
- **Pub/Sub**: No dependencies
- **VPC**: No dependencies
- **Subnet**: Depends on VPC
- **Firewall**: Depends on VPC

### Phase 2 Dependencies
- **Cloud Functions**: Depends on VPC and Pub/Sub
- **API Gateway**: Depends on Cloud Functions
- **Identity Platform**: No dependencies
- **Cloud KMS**: No dependencies
- **Monitoring**: Depends on all other resources
- **Firestore Indexes**: Depends on Firestore Database

## Security Considerations

### Network Security
- VPC isolation for all resources
- Environment-specific firewall rules
- Restricted access in production
- Private Google access enabled

### Data Security
- Encryption at rest for all storage
- Encryption in transit for all communications
- KMS key management for sensitive data
- Audit logging for all operations

### Access Control
- IAM roles with least privilege
- Service account management
- Environment-specific permissions
- Regular access reviews

## Cost Optimization

### Development Environment
- Minimal resource allocation
- Auto-scaling disabled
- Basic monitoring only
- Cost alerts enabled

### Staging Environment
- Production-like configuration
- Full monitoring enabled
- Performance testing resources
- Cost optimization testing

### Production Environment
- Optimized resource allocation
- Auto-scaling enabled
- Full monitoring and alerting
- Cost monitoring and optimization

## Monitoring and Observability

### Infrastructure Monitoring
- Resource utilization tracking
- Performance metrics collection
- Error rate monitoring
- Cost tracking and alerts

### Application Monitoring
- API endpoint monitoring
- Function execution tracking
- Database performance monitoring
- User experience metrics

### Security Monitoring
- Access pattern analysis
- Security event logging
- Compliance reporting
- Threat detection

## Conclusion

This backend infrastructure provides a comprehensive, scalable, and secure foundation for modern cloud applications. The 2-step deployment approach ensures reliable resource creation while the centralized helper files maintain consistency across environments.

Key benefits:
1. **Reliable deployments** through phased approach
2. **Environment isolation** with separate configurations
3. **Security by design** with comprehensive controls
4. **Scalability** through modular architecture
5. **Maintainability** through centralized management

