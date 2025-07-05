# Monitoring Module
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
  description = "The region to deploy monitoring resources"
  type        = string
  default     = "us-central1"
}

variable "monitoring_config" {
  description = "Monitoring configuration"
  type        = map(any)
  default     = {}
}

# Outputs
output "log_sinks" {
  description = "Created log sinks"
  value       = {}
}

output "uptime_checks" {
  description = "Created uptime checks"
  value       = {}
} 