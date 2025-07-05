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
  description = "The region to deploy Cloud Functions"
  type        = string
  default     = "us-central1"
}

variable "functions" {
  description = "Map of Cloud Function configurations"
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