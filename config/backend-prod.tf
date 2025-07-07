# =============================================================================
# PRODUCTION BACKEND CONFIGURATION
# =============================================================================
# This file contains the backend configuration for the production environment

terraform {
  backend "gcs" {
    bucket = "tf-state-prod-2"
    prefix = "terraform/state"
  }
} 