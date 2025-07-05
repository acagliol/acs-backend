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
  description = "The region to deploy Cloud KMS (defined centrally in variables.tf)"
  type        = string
  default     = "us-central1"
}

variable "keyrings" {
  description = "Map of Cloud KMS keyring configurations (defined centrally in variables.tf)"
  type        = map(any)
  default     = {}
}

# Outputs
output "keyring_names" {
  description = "Names of the created Cloud KMS keyrings"
  value       = []
}

output "crypto_key_names" {
  description = "Names of the created Cloud KMS crypto keys"
  value       = []
} 