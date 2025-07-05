# =============================================================================
# VARIABLE DECLARATIONS
# =============================================================================
# This file contains all variable declarations for the Terraform configuration
# Variables are used across main-independent.tf and main-dependent.tf

variable "environment" {
  description = "Environment to deploy (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
  default     = null

  validation {
    condition     = var.project_id == null || can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be 6-30 characters long, contain only lowercase letters, numbers, and hyphens, and start with a letter."
  }
}

variable "region" {
  description = "Google Cloud region for resources"
  type        = string
  default     = "us-central1"

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]*$", var.region))
    error_message = "Region must be a valid Google Cloud region (e.g., us-central1, europe-west1)."
  }
}

