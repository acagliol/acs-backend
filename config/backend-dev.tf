# =============================================================================
# DEVELOPMENT BACKEND CONFIGURATION
# =============================================================================
# This file contains the backend configuration for the development environment

terraform {
  backend "gcs" {
    bucket = "tf-state-dev-2"
    prefix = "terraform/state"
  }
} 