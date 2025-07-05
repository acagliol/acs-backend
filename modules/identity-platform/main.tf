# Identity Platform Module
# This module creates Identity Platform for authentication

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
  description = "The region to deploy Identity Platform"
  type        = string
  default     = "us-central1"
}

variable "identity_platform_config" {
  description = "Identity Platform configuration"
  type = object({
    display_name = string
    support_email = string
    authorized_domains = optional(list(string), [])
    sign_in_options = list(object({
      provider = string # "google", "facebook", "twitter", "github", "email"
      enabled = bool
      display_name = optional(string, "")
      provider_config = optional(map(string), {})
    }))
    password_policy = optional(object({
      allow_numeric_characters = optional(bool, true)
      allow_uppercase_characters = optional(bool, true)
      allow_lowercase_characters = optional(bool, true)
      allow_special_characters = optional(bool, true)
      min_password_length = optional(number, 8)
      max_password_length = optional(number, 100)
    }), {})
    email_config = optional(object({
      enabled = optional(bool, true)
      require_email_verification = optional(bool, true)
      allow_duplicate_emails = optional(bool, false)
    }), {})
    sms_config = optional(object({
      enabled = optional(bool, false)
      test_phone_numbers = optional(map(string), {})
    }), {})
  })
}

# Locals
locals {
  common_labels = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "identity-platform"
  }
}

# Identity Platform Project Default Config
resource "google_identity_platform_project_default_config" "default_config" {
  project = var.project_id
  
  sign_in {
    allow_duplicate_emails = var.identity_platform_config.email_config.allow_duplicate_emails
    
    dynamic "anonymous" {
      for_each = [
        for option in var.identity_platform_config.sign_in_options : option
        if option.provider == "anonymous"
      ]
      content {
        enabled = anonymous.value.enabled
      }
    }
    
    dynamic "email" {
      for_each = [
        for option in var.identity_platform_config.sign_in_options : option
        if option.provider == "email"
      ]
      content {
        enabled = email.value.enabled
        password_required = true
      }
    }
    
    dynamic "phone_number" {
      for_each = [
        for option in var.identity_platform_config.sign_in_options : option
        if option.provider == "phone"
      ]
      content {
        enabled = phone_number.value.enabled
        test_phone_numbers = var.identity_platform_config.sms_config.test_phone_numbers
      }
    }
  }
  
  sign_in {
    allow_duplicate_emails = var.identity_platform_config.email_config.allow_duplicate_emails
  }
  
  notification {
    send_email {
      method = "DEFAULT"
    }
    send_sms {
      method = "DEFAULT"
    }
  }
  
  quota {
    sign_up_quota_config {
      quota = 1000
      start_time = "2023-01-01T00:00:00Z"
    }
  }
  
  monitoring {
    request_logging {
      enabled = true
    }
  }
}

# Identity Platform OAuth IDP Configs
resource "google_identity_platform_oauth_idp_config" "oauth_configs" {
  for_each = {
    for option in var.identity_platform_config.sign_in_options : option.provider => option
    if contains(["google", "facebook", "twitter", "github"], option.provider)
  }
  
  name         = "${each.value.provider}-${var.environment}"
  display_name = each.value.display_name != "" ? each.value.display_name : title(each.value.provider)
  enabled      = each.value.enabled
  project      = var.project_id
  
  client_id     = each.value.provider_config.client_id
  client_secret = each.value.provider_config.client_secret
  
  issuer = each.value.provider_config.issuer
}

# Identity Platform Tenant (for multi-tenancy if needed)
resource "google_identity_platform_tenant" "tenant" {
  count = var.environment == "prod" ? 1 : 0
  
  display_name  = "${var.identity_platform_config.display_name} - ${title(var.environment)}"
  allow_password_signup = true
  project       = var.project_id
}

# Service Account for Identity Platform
resource "google_service_account" "identity_platform_sa" {
  account_id   = "identity-platform-sa-${var.environment}"
  display_name = "Identity Platform Service Account for ${var.environment}"
  project      = var.project_id
}

# IAM binding for Identity Platform service account
resource "google_project_iam_member" "identity_platform_iam" {
  project = var.project_id
  role    = "roles/identityplatform.admin"
  member  = "serviceAccount:${google_service_account.identity_platform_sa.email}"
}

# Outputs
output "project_id" {
  description = "The project ID where Identity Platform is configured"
  value       = var.project_id
}

output "tenant_id" {
  description = "The tenant ID (if created)"
  value       = var.environment == "prod" ? google_identity_platform_tenant.tenant[0].name : null
}

output "service_account_email" {
  description = "The email of the Identity Platform service account"
  value       = google_service_account.identity_platform_sa.email
}

output "oauth_configs" {
  description = "The OAuth IDP configurations"
  value = {
    for k, v in google_identity_platform_oauth_idp_config.oauth_configs : k => {
      name = v.name
      display_name = v.display_name
      enabled = v.enabled
    }
  }
} 