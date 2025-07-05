# API Gateway Module
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
  description = "The region to deploy API Gateway (defined centrally in variables.tf)"
  type        = string
  default     = "us-central1"
}

variable "api_config" {
  description = "API Gateway configuration (defined centrally in variables.tf)"
  type        = map(any)
  default     = {}
}

# Outputs
output "gateway_url" {
  description = "URL of the API Gateway"
  value       = ""
}

output "api_id" {
  description = "ID of the API Gateway"
  value       = ""
} 