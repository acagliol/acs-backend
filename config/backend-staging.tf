# =============================================================================
# STAGING BACKEND CONFIGURATION
# =============================================================================
# This file contains the backend configuration for the staging environment

terraform {
  backend "gcs" {
    bucket = "tf-state-staging-2"
    prefix = "terraform/state"
  }
} 