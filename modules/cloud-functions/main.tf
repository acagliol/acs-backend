# Cloud Functions Module
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
  description = "The region to deploy Cloud Functions (defined centrally in variables.tf)"
  type        = string
  default     = "us-central1"
}

variable "functions" {
  description = "Map of Cloud Function configurations (defined centrally in variables.tf)"
  type        = map(any)
  default     = {}
}

# Outputs
output "function_urls" {
  description = "URLs of the deployed Cloud Functions"
  value       = {}
}

output "function_names" {
  description = "Names of the deployed Cloud Functions"
  value       = {}
} 