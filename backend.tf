# Backend configuration for remote state storage
# This configuration dynamically uses the environment-specific bucket

terraform {
  backend "gcs" {
    # These values will be provided via -backend-config flags
    # bucket = "tf-state-{environment}-2"
    # prefix = "terraform/state"
  }
} 