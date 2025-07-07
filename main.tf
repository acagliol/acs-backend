# =============================================================================
# MAIN TERRAFORM CONFIGURATION
# =============================================================================
# This file consolidates all resources into a single deployment
# No more two-phase deployment - everything deploys together with proper dependencies

# =============================================================================
# OUTPUTS
# =============================================================================

output "environment_config" {
  description = "Current environment configuration"
  value       = local.env_config
}

# =============================================================================
# FIRESTORE DATABASES (Phase 1 - Independent Resources)
# =============================================================================

# Primary Firestore database
resource "google_firestore_database" "database" {
  name        = "db-dev"
  location_id = local.env_config.region
  type        = "FIRESTORE_NATIVE"
}

# Output for primary Firestore database
output "firestore_database" {
  description = "Primary Firestore database information"
  value = {
    name        = google_firestore_database.database.name
    location_id = google_firestore_database.database.location_id
    type        = google_firestore_database.database.type
    project     = google_firestore_database.database.project
  }
}

# Secondary Firestore database (if needed)
resource "google_firestore_database" "database2" {
  name        = "db-dev2"
  location_id = local.env_config.region
  type        = "FIRESTORE_NATIVE"
}

# Output for secondary Firestore database
output "firestore_database_2" {
  description = "Secondary Firestore database information"
  value = {
    name        = google_firestore_database.database2.name
    location_id = google_firestore_database.database2.location_id
    type        = google_firestore_database.database2.type
    project     = google_firestore_database.database2.project
  }
}

# =============================================================================
# MODULES (Phase 2 - Dependent Resources)
# =============================================================================

# Firestore Module (Collections and Indexes)
module "firestore" {
  source = "./modules/firestore"

  project_id    = local.env_config.project_id
  environment   = local.environment
  location_id   = local.env_config.region
  database_name = "db-dev"
  database_id   = google_firestore_database.database.id

  depends_on = [google_firestore_database.database]
}

# Cloud Functions Module (Lambda equivalent)
module "cloud_functions" {
  source = "./modules/cloud-functions"

  project_id  = local.env_config.project_id
  environment = local.environment
  region      = local.env_config.region
  functions   = {}

  depends_on = [google_firestore_database.database]
}

# API Gateway Module
module "api_gateway" {
  source = "./modules/api-gateway"

  project_id  = local.env_config.project_id
  environment = local.environment
  region      = local.env_config.region
  api_config  = {}

  depends_on = [google_firestore_database.database]
}

# Cloud Storage Module (S3 equivalent)
module "cloud_storage" {
  source = "./modules/cloud-storage"

  project_id  = local.env_config.project_id
  environment = local.environment
  region      = local.env_config.region
  buckets     = {}

  depends_on = [google_firestore_database.database]
}

# Pub/Sub Module (SQS equivalent)
module "pub_sub" {
  source = "./modules/pub-sub"

  project_id    = local.env_config.project_id
  environment   = local.environment
  region        = local.env_config.region
  topics        = {}
  subscriptions = {}

  depends_on = [google_firestore_database.database]
}

# Identity Platform Module (Cognito equivalent)
module "identity_platform" {
  source = "./modules/identity-platform"

  project_id               = local.env_config.project_id
  environment              = local.environment
  region                   = local.env_config.region
  identity_platform_config = {}

  depends_on = [google_firestore_database.database]
}

# Cloud KMS Module (Encryption)
module "cloud_kms" {
  source = "./modules/cloud-kms"

  project_id  = local.env_config.project_id
  environment = local.environment
  region      = local.env_config.region
  keyrings    = {}

  depends_on = [google_firestore_database.database]
}

# Monitoring Module (CloudWatch equivalent)
module "monitoring" {
  source = "./modules/monitoring"

  project_id        = local.env_config.project_id
  environment       = local.environment
  region            = local.env_config.region
  monitoring_config = {}

  depends_on = [google_firestore_database.database]
}

# =============================================================================
# NETWORKING RESOURCES
# =============================================================================
# Add any networking resources here as needed

# =============================================================================
# FINAL OUTPUTS
# =============================================================================

output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    environment   = local.environment
    project_id    = local.env_config.project_id
    region        = local.env_config.region
    firestore_dbs = [google_firestore_database.database.name, google_firestore_database.database2.name]
    modules_deployed = [
      "firestore",
      "cloud_functions",
      "api_gateway",
      "cloud_storage",
      "pub_sub",
      "identity_platform",
      "cloud_kms",
      "monitoring"
    ]
  }
} 