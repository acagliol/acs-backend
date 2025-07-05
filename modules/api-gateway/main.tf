# API Gateway Module
# This module creates API Gateway for frontend integration

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
  type = object({
    api_id = string
    display_name = string
    description = optional(string, "")
    endpoints = map(object({
      name = string
      path = string
      method = string
      function_name = string
      function_region = optional(string, "us-central1")
      auth_required = optional(bool, false)
      cors_enabled = optional(bool, true)
    }))
  })
}

# Locals
locals {
  common_labels = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "api-gateway"
  }
}

# API Gateway API
resource "google_api_gateway_api" "api" {
  provider = google-beta
  api_id   = "${var.api_config.api_id}-${var.environment}"
  project  = var.project_id
}

# API Gateway API Config
resource "google_api_gateway_api_config" "api_cfg" {
  provider      = google-beta
  api           = google_api_gateway_api.api.api_id
  api_config_id = "${var.api_config.api_id}-config-${var.environment}"
  project       = var.project_id

  openapi_documents {
    document {
      path = "spec.yaml"
      contents = base64encode(templatefile("${path.module}/templates/api-spec.yaml.tftpl", {
        project_id = var.project_id
        region     = var.region
        endpoints  = var.api_config.endpoints
        environment = var.environment
      }))
    }
  }

  gateway_config {
    backend_config {
      google_service_account = google_service_account.api_gateway_sa.email
    }
  }
}

# API Gateway Gateway
resource "google_api_gateway_gateway" "gateway" {
  provider   = google-beta
  region     = var.region
  api_config = google_api_gateway_api_config.api_cfg.id
  project    = var.project_id

  gateway_id = "${var.api_config.api_id}-gateway-${var.environment}"
}

# Service Account for API Gateway
resource "google_service_account" "api_gateway_sa" {
  account_id   = "api-gateway-sa-${var.environment}"
  display_name = "API Gateway Service Account for ${var.environment}"
  project      = var.project_id
}

# IAM binding for API Gateway to invoke Cloud Functions
resource "google_cloudfunctions2_function_iam_member" "invoker" {
  for_each = var.api_config.endpoints
  
  project        = var.project_id
  location       = each.value.function_region
  cloud_function = each.value.function_name
  role           = "roles/cloudfunctions.invoker"
  member         = "serviceAccount:${google_service_account.api_gateway_sa.email}"
}

# Outputs
output "gateway_url" {
  description = "The URL of the API Gateway"
  value       = google_api_gateway_gateway.gateway.default_hostname
}

output "api_id" {
  description = "The ID of the API Gateway API"
  value       = google_api_gateway_api.api.api_id
}

output "gateway_id" {
  description = "The ID of the API Gateway Gateway"
  value       = google_api_gateway_gateway.gateway.gateway_id
}

output "service_account_email" {
  description = "The email of the API Gateway service account"
  value       = google_service_account.api_gateway_sa.email
} 