# =============================================================================
# TERRAFORM VARIABLES FILE
# =============================================================================
# This file contains default values for Terraform variables
# Environment-specific values are loaded from environments/{env}.json files

# Default environment (can be overridden with -var="environment=staging")
environment = "dev"

# Default region (can be overridden with -var="region=us-west1")
region = "us-central1"

# Project ID will be loaded from environment JSON file
# project_id = "acs-dev-464702"

# SSH access control (empty for dev, should be configured for prod)
