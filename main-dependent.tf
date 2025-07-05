# Phase 2 Configuration - Dependent Resources
# This file contains resources that depend on Phase 1 resources

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

# =============================================================================
# MODULE: Firestore (Database)
# =============================================================================
module "firestore" {
  source = "./modules/firestore"

  project_id    = local.env_config.project_id
  environment   = local.environment
  location_id   = local.env_config.region
  database_name = "db-dev"
}

# =============================================================================
# MODULE: Cloud Functions (Lambda equivalent)
# =============================================================================
module "cloud_functions" {
  source = "./modules/cloud-functions"

  project_id  = local.env_config.project_id
  environment = local.environment
  region      = local.env_config.region
  functions   = {}
}

# =============================================================================
# MODULE: API Gateway
# =============================================================================
module "api_gateway" {
  source = "./modules/api-gateway"

  project_id  = local.env_config.project_id
  environment = local.environment
  region      = local.env_config.region
  api_config  = {}
}

# =============================================================================
# MODULE: Cloud Storage (S3 equivalent)
# =============================================================================
module "cloud_storage" {
  source = "./modules/cloud-storage"

  project_id  = local.env_config.project_id
  environment = local.environment
  region      = local.env_config.region
  buckets     = {}
}

# =============================================================================
# MODULE: Pub/Sub (SQS equivalent)
# =============================================================================
module "pub_sub" {
  source = "./modules/pub-sub"

  project_id    = local.env_config.project_id
  environment   = local.environment
  region        = local.env_config.region
  topics        = {}
  subscriptions = {}
}

# =============================================================================
# MODULE: Identity Platform (Cognito equivalent)
# =============================================================================
module "identity_platform" {
  source = "./modules/identity-platform"

  project_id               = local.env_config.project_id
  environment              = local.environment
  region                   = local.env_config.region
  identity_platform_config = {}
}

# =============================================================================
# MODULE: Cloud KMS (Encryption)
# =============================================================================
module "cloud_kms" {
  source = "./modules/cloud-kms"

  project_id  = local.env_config.project_id
  environment = local.environment
  region      = local.env_config.region
  keyrings    = {}
}

# =============================================================================
# MODULE: Monitoring (CloudWatch equivalent)
# =============================================================================
module "monitoring" {
  source = "./modules/monitoring"

  project_id        = local.env_config.project_id
  environment       = local.environment
  region            = local.env_config.region
  monitoring_config = {}
}

# =============================================================================
# NETWORKING RESOURCES
# =============================================================================

# =============================================================================
# OUTPUTS FOR PHASE 2 RESOURCES
# =============================================================================


# =============================================================================
# VARIABLES
# =============================================================================
# Variables are now defined centrally in variables.tf
# This file references the following variables from variables.tf:
# - var.environment
# - var.allowed_ssh_ips
# - var.allowed_web_ips
# - var.subnet_config
