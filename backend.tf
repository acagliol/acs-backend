# Backend configuration for remote state storage
# This configuration dynamically uses the environment-specific bucket

terraform {
  backend "gcs" {
    # These values will be provided via -backend-config flags
    # bucket = "terraform-state-{environment}-anay"
    # prefix = "terraform/state"
  }
} 