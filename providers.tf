# =============================================================================
# PROVIDER CONFIGURATIONS
# =============================================================================

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