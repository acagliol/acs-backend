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

# Variables
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "region" {
  description = "The region to deploy Identity Platform"
  type        = string
  default     = "us-central1"
}

variable "identity_platform_config" {
  description = "Identity Platform configuration"
  type        = map(any)
  default     = {}
}

# Outputs
output "project_id" {
  description = "The project ID for Identity Platform"
  value       = var.project_id
}

output "tenant_id" {
  description = "The tenant ID for Identity Platform"
  value       = ""
} 