# Cloud Storage Module
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
  description = "The region to deploy Cloud Storage (defined centrally in variables.tf)"
  type        = string
  default     = "us-central1"
}

variable "buckets" {
  description = "Map of Cloud Storage bucket configurations (defined centrally in variables.tf)"
  type        = map(any)
  default     = {}
}

# Outputs
output "bucket_names" {
  description = "Names of the created Cloud Storage buckets"
  value       = []
}

output "bucket_urls" {
  description = "URLs of the created Cloud Storage buckets"
  value       = []
} 