# Cloud KMS Module
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
  description = "The region to deploy Cloud KMS resources"
  type        = string
  default     = "us-central1"
}

variable "keyrings" {
  description = "Map of Cloud KMS keyring configurations"
  type        = map(any)
  default     = {}
}

# Outputs
output "keyring_names" {
  description = "Names of the created Cloud KMS keyrings"
  value       = {}
}

output "crypto_key_names" {
  description = "Names of the created Cloud KMS crypto keys"
  value       = {}
} 