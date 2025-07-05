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
  description = "The region to deploy Cloud Storage buckets"
  type        = string
  default     = "us-central1"
}

variable "buckets" {
  description = "Map of Cloud Storage bucket configurations"
  type        = map(any)
  default     = {}
}

# Outputs
output "bucket_names" {
  description = "Names of the created Cloud Storage buckets"
  value       = {}
}

output "bucket_urls" {
  description = "URLs of the created Cloud Storage buckets"
  value       = {}
} 