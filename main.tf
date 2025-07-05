# Modular Terraform Configuration
# This configuration uses modules to organize resources by service type
# and reads environment-specific settings from JSON files

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

# Load environment configuration
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

# Configure Google Cloud Provider
provider "google" {
  project = local.env_config.project_id
  region  = local.env_config.region
  zone    = local.env_config.zone
}

provider "google-beta" {
  project = local.env_config.project_id
  region  = local.env_config.region
  zone    = local.env_config.zone
}

# =============================================================================
# MODULE: Firestore (Database)
# =============================================================================
module "firestore" {
  source = "./modules/firestore"
  
  project_id   = local.env_config.project_id
  environment  = local.environment
  database_id  = local.env_config.firestore.database_id
  location_id  = local.env_config.firestore.location_id
  database_type = local.env_config.firestore.database_type
  collections  = local.env_config.firestore.collections
}

# =============================================================================
# MODULE: Cloud Functions (Lambda equivalent)
# =============================================================================
module "cloud_functions" {
  source = "./modules/cloud-functions"
  
  project_id  = local.env_config.project_id
  environment = local.environment
  region      = local.env_config.cloud_functions.region
  functions   = local.env_config.cloud_functions.functions
}

# =============================================================================
# MODULE: API Gateway
# =============================================================================
module "api_gateway" {
  source = "./modules/api-gateway"
  
  project_id  = local.env_config.project_id
  environment = local.environment
  region      = local.env_config.api_gateway.region
  api_config  = local.env_config.api_gateway.api_config
}

# =============================================================================
# MODULE: Cloud Storage (S3 equivalent)
# =============================================================================
module "cloud_storage" {
  source = "./modules/cloud-storage"
  
  project_id  = local.env_config.project_id
  environment = local.environment
  region      = local.env_config.cloud_storage.region
  buckets     = local.env_config.cloud_storage.buckets
}

# =============================================================================
# MODULE: Pub/Sub (SQS equivalent)
# =============================================================================
module "pub_sub" {
  source = "./modules/pub-sub"
  
  project_id     = local.env_config.project_id
  environment    = local.environment
  region         = local.env_config.pub_sub.region
  topics         = local.env_config.pub_sub.topics
  subscriptions  = local.env_config.pub_sub.subscriptions
}

# =============================================================================
# MODULE: Identity Platform (Cognito equivalent)
# =============================================================================
module "identity_platform" {
  source = "./modules/identity-platform"
  
  project_id  = local.env_config.project_id
  environment = local.environment
  region      = local.env_config.identity_platform.region
  identity_platform_config = local.env_config.identity_platform.identity_platform_config
}

# =============================================================================
# MODULE: Cloud KMS (Encryption)
# =============================================================================
module "cloud_kms" {
  source = "./modules/cloud-kms"
  
  project_id  = local.env_config.project_id
  environment = local.environment
  region      = local.env_config.cloud_kms.region
  keyrings    = local.env_config.cloud_kms.keyrings
}

# =============================================================================
# MODULE: Monitoring (CloudWatch equivalent)
# =============================================================================
module "monitoring" {
  source = "./modules/monitoring"
  
  project_id  = local.env_config.project_id
  environment = local.environment
  region      = local.env_config.monitoring.region
  monitoring_config = local.env_config.monitoring.monitoring_config
}

# =============================================================================
# NETWORKING RESOURCES
# =============================================================================

# VPC Network
resource "google_compute_network" "vpc" {
  name                    = "vpc-${local.environment}"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  project                 = local.env_config.project_id
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "subnet-${local.environment}"
  ip_cidr_range = "10.0.1.0/24"  # You can add this to your JSON config
  network       = google_compute_network.vpc.id
  region        = local.env_config.region
  project       = local.env_config.project_id
}

# Firewall rule for HTTP/HTTPS
resource "google_compute_firewall" "allow_web" {
  name    = "allow-web-${local.environment}"
  network = google_compute_network.vpc.name
  project = local.env_config.project_id

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web"]
}

# Firewall rule for SSH (restricted to specific IPs in production)
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
}

# =============================================================================
# OUTPUTS
# =============================================================================

# Firestore outputs
output "firestore_database_name" {
  description = "Name of the Firestore database"
  value       = module.firestore.database_name
}

output "firestore_collections" {
  description = "List of Firestore collections"
  value       = module.firestore.collection_names
}

# Cloud Functions outputs
output "cloud_function_urls" {
  description = "URLs of the deployed Cloud Functions"
  value       = module.cloud_functions.function_urls
}

output "cloud_function_names" {
  description = "Names of the deployed Cloud Functions"
  value       = module.cloud_functions.function_names
}

# API Gateway outputs
output "api_gateway_url" {
  description = "URL of the API Gateway"
  value       = module.api_gateway.gateway_url
}

output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = module.api_gateway.api_id
}

# Cloud Storage outputs
output "storage_bucket_names" {
  description = "Names of the created Cloud Storage buckets"
  value       = module.cloud_storage.bucket_names
}

output "storage_bucket_urls" {
  description = "URLs of the created Cloud Storage buckets"
  value       = module.cloud_storage.bucket_urls
}

# Pub/Sub outputs
output "pubsub_topic_names" {
  description = "Names of the created Pub/Sub topics"
  value       = module.pub_sub.topic_names
}

output "pubsub_subscription_names" {
  description = "Names of the created Pub/Sub subscriptions"
  value       = module.pub_sub.subscription_names
}

# Identity Platform outputs
output "identity_platform_project_id" {
  description = "Project ID where Identity Platform is configured"
  value       = module.identity_platform.project_id
}

output "identity_platform_tenant_id" {
  description = "Tenant ID (if created)"
  value       = module.identity_platform.tenant_id
}

# Cloud KMS outputs
output "kms_keyring_names" {
  description = "Names of the created Cloud KMS keyrings"
  value       = module.cloud_kms.keyring_names
}

output "kms_crypto_key_names" {
  description = "Names of the created Cloud KMS crypto keys"
  value       = module.cloud_kms.crypto_key_names
}

# Monitoring outputs
output "monitoring_log_sinks" {
  description = "Names of the created log sinks"
  value       = module.monitoring.log_sink_names
}

output "monitoring_uptime_checks" {
  description = "Names of the created uptime checks"
  value       = module.monitoring.uptime_check_names
}

# Networking outputs
output "vpc_name" {
  description = "Name of the VPC"
  value       = google_compute_network.vpc.name
}

output "subnet_name" {
  description = "Name of the subnet"
  value       = google_compute_subnetwork.subnet.name
}

# =============================================================================
# VARIABLES
# =============================================================================

variable "environment" {
  description = "Environment to deploy (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "allowed_ssh_ips" {
  description = "List of IP addresses allowed to SSH to instances in production"
  type        = list(string)
  default     = []
}
