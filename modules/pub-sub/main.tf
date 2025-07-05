# Pub/Sub Module
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
  description = "The region to deploy Pub/Sub (defined centrally in variables.tf)"
  type        = string
  default     = "us-central1"
}

variable "topics" {
  description = "Map of Pub/Sub topic configurations (defined centrally in variables.tf)"
  type        = map(any)
  default     = {}
}

variable "subscriptions" {
  description = "Map of Pub/Sub subscription configurations (defined centrally in variables.tf)"
  type        = map(any)
  default     = {}
}

# Outputs
output "topic_names" {
  description = "Names of the created Pub/Sub topics"
  value       = []
}

output "subscription_names" {
  description = "Names of the created Pub/Sub subscriptions"
  value       = []
} 