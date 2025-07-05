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
  description = "The region to deploy API Gateway"
  type        = string
  default     = "us-central1"
}

variable "api_config" {
  description = "API Gateway configuration"
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