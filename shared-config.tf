# Shared Configuration - Common locals and variables
# This file contains shared configuration that both Phase 1 and Phase 2 use

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