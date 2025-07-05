# Cloud Storage Module
# This module creates Cloud Storage buckets for data storage

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
  description = "The region to deploy Cloud Storage buckets"
  type        = string
  default     = "us-central1"
}

variable "buckets" {
  description = "Map of Cloud Storage bucket configurations"
  type = map(object({
    name = string
    location = optional(string, "US")
    storage_class = optional(string, "STANDARD")
    uniform_bucket_level_access = optional(bool, true)
    public_access_prevention = optional(string, "enforced")
    versioning = optional(bool, false)
    lifecycle_rules = optional(list(object({
      action = object({
        type = string
        storage_class = optional(string)
      })
      condition = object({
        age = optional(number)
        days_since_noncurrent_time = optional(number)
        noncurrent_time_before = optional(string)
        created_before = optional(string)
        matches_storage_class = optional(list(string))
        num_newer_versions = optional(number)
        with_state = optional(string)
      })
    })), [])
    cors = optional(list(object({
      origin = list(string)
      method = list(string)
      response_header = list(string)
      max_age_seconds = optional(number, 3600)
    })), [])
    labels = optional(map(string), {})
  }))
  default = {}
}

# Locals
locals {
  common_labels = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "cloud-storage"
  }
}

# Cloud Storage Buckets
resource "google_storage_bucket" "buckets" {
  for_each = var.buckets
  
  name          = "${each.value.name}-${var.project_id}-${var.environment}"
  location      = each.value.location
  project       = var.project_id
  storage_class = each.value.storage_class
  force_destroy = var.environment != "prod" # Allow destruction in non-prod environments
  
  uniform_bucket_level_access = each.value.uniform_bucket_level_access
  public_access_prevention    = each.value.public_access_prevention
  
  versioning {
    enabled = each.value.versioning
  }
  
  dynamic "lifecycle_rule" {
    for_each = each.value.lifecycle_rules
    content {
      action {
        type          = lifecycle_rule.value.action.type
        storage_class = lifecycle_rule.value.action.storage_class
      }
      condition {
        age                        = lifecycle_rule.value.condition.age
        days_since_noncurrent_time = lifecycle_rule.value.condition.days_since_noncurrent_time
        noncurrent_time_before     = lifecycle_rule.value.condition.noncurrent_time_before
        created_before             = lifecycle_rule.value.condition.created_before
        matches_storage_class      = lifecycle_rule.value.condition.matches_storage_class
        num_newer_versions         = lifecycle_rule.value.condition.num_newer_versions
        with_state                 = lifecycle_rule.value.condition.with_state
      }
    }
  }
  
  dynamic "cors" {
    for_each = each.value.cors
    content {
      origin          = cors.value.origin
      method          = cors.value.method
      response_header = cors.value.response_header
      max_age_seconds = cors.value.max_age_seconds
    }
  }
  
  labels = merge(local.common_labels, each.value.labels)
}

# IAM bindings for Cloud Storage buckets
resource "google_storage_bucket_iam_member" "bucket_iam" {
  for_each = {
    for k, v in var.buckets : k => v
    if contains(keys(v), "iam_members")
  }
  
  bucket = google_storage_bucket.buckets[each.key].name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${var.project_id}@appspot.gserviceaccount.com"
}

# Outputs
output "bucket_names" {
  description = "Names of the created Cloud Storage buckets"
  value = {
    for k, v in google_storage_bucket.buckets : k => v.name
  }
}

output "bucket_urls" {
  description = "URLs of the created Cloud Storage buckets"
  value = {
    for k, v in google_storage_bucket.buckets : k => "gs://${v.name}"
  }
}

output "bucket_self_links" {
  description = "Self links of the created Cloud Storage buckets"
  value = {
    for k, v in google_storage_bucket.buckets : k => v.self_link
  }
} 