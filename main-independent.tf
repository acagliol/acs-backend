# Phase 1 Configuration - Independent Resources Only
# This file contains resources that must be created first and don't depend on other resources

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

# Phase 1 Configuration - Core Infrastructure
# These resources are independent and can be created first

# Outputs for Phase 1 resources
output "environment_config" {
  description = "Current environment configuration"
  value       = local.env_config
}



# Firestore database creation
resource "google_firestore_database" "database" {
  name        = "db-dev"
  location_id = local.env_config.region
  type        = "FIRESTORE_NATIVE"
}

# Output for Firestore database
output "firestore_database" {
  description = "Firestore database information"
  value = {
    name        = google_firestore_database.database.name
    location_id = google_firestore_database.database.location_id
    type        = google_firestore_database.database.type
    project     = google_firestore_database.database.project
  }
}
