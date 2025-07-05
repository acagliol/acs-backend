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
  description = "The region to deploy Pub/Sub resources"
  type        = string
  default     = "us-central1"
}

variable "topics" {
  description = "Map of Pub/Sub topic configurations"
  type        = map(any)
  default     = {}
}

variable "subscriptions" {
  description = "Map of Pub/Sub subscription configurations"
  type        = map(any)
  default     = {}
}

# Outputs
output "topic_names" {
  description = "Names of the created Pub/Sub topics"
  value       = {}
}

output "subscription_names" {
  description = "Names of the created Pub/Sub subscriptions"
  value       = {}
} 