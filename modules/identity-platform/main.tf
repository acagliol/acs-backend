# Identity Platform Module
# This module will be implemented later

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

# =============================================================================
# VARIABLE DECLARATIONS
# =============================================================================
# These variables are defined centrally in the root variables.tf file
# and are referenced here for module use.

variable "project_id" {
  description = "The GCP project ID (defined centrally in variables.tf)"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod) (defined centrally in variables.tf)"
  type        = string
}

variable "region" {
  description = "The region to deploy Identity Platform (defined centrally in variables.tf)"
  type        = string
  default     = "us-central1"
}

variable "identity_platform_config" {
  description = "Identity Platform configuration (defined centrally in variables.tf)"
  type        = map(any)
  default     = {}
}

# Outputs
output "project_id" {
  description = "Project ID where Identity Platform is configured"
  value       = var.project_id
}

output "tenant_id" {
  description = "Tenant ID (if created)"
  value       = ""
} 