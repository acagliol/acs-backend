# Phase 1 Configuration - Independent Resources Only
# This file contains resources that must be created first and don't depend on other resources
# Shared configuration is loaded from shared-config.tf

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


# create a new database db-dev2
resource "google_firestore_database" "database2" {
  name        = "db-dev2"
  location_id = local.env_config.region
  type        = "FIRESTORE_NATIVE"
}

# Output for Firestore database
output "firestore_database_2" {
  description = "Firestore database information"
  value = {
    name        = google_firestore_database.database2.name
    location_id = google_firestore_database.database2.location_id
    type        = google_firestore_database.database2.type
    project     = google_firestore_database.database2.project
  }
}
