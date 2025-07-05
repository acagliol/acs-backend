# Cloud Functions Module
# This module creates Cloud Functions for business logic

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
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
  description = "The region to deploy Cloud Functions"
  type        = string
  default     = "us-central1"
}

variable "functions" {
  description = "Map of Cloud Function configurations"
  type = map(object({
    name        = string
    description = optional(string, "")
    runtime     = string
    entry_point = string
    source_dir  = string
    trigger_type = string # "http", "pubsub", "storage", "eventarc"
    trigger_config = optional(map(string), {})
    environment_variables = optional(map(string), {})
    memory_mb   = optional(number, 256)
    timeout_seconds = optional(number, 60)
    available_memory_mb = optional(number, 256)
    max_instances = optional(number, 100)
    min_instances = optional(number, 0)
    service_account_email = optional(string, "")
    vpc_connector = optional(string, "")
    ingress_settings = optional(string, "ALLOW_ALL")
  }))
  default = {}
}

# Locals
locals {
  common_labels = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "cloud-functions"
  }
}

# Cloud Functions
resource "google_cloudfunctions2_function" "functions" {
  for_each = var.functions
  
  name        = "${each.value.name}-${var.environment}"
  description = each.value.description
  location    = var.region
  project     = var.project_id

  build_config {
    runtime     = each.value.runtime
    entry_point = each.value.entry_point
    source {
      storage_source {
        bucket = google_storage_bucket.source_bucket.name
        object = google_storage_bucket_object.source_objects[each.key].name
      }
    }
  }

  service_config {
    max_instance_count = each.value.max_instances
    min_instance_count = each.value.min_instances
    available_memory   = "${each.value.available_memory_mb}M"
    timeout_seconds    = each.value.timeout_seconds
    environment_variables = each.value.environment_variables
    service_account_email = each.value.service_account_email != "" ? each.value.service_account_email : null
    vpc_connector = each.value.vpc_connector != "" ? each.value.vpc_connector : null
    ingress_settings = each.value.ingress_settings
  }

  dynamic "event_trigger" {
    for_each = each.value.trigger_type != "http" ? [1] : []
    content {
      trigger_region = var.region
      event_type     = each.value.trigger_config.event_type
      event_filters {
        attribute = each.value.trigger_config.attribute
        value     = each.value.trigger_config.value
      }
    }
  }
}

# Source code storage bucket
resource "google_storage_bucket" "source_bucket" {
  name     = "cloud-functions-source-${var.project_id}-${var.environment}"
  location = var.region
  project  = var.project_id
  
  uniform_bucket_level_access = true
  
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
}

# Source code objects
resource "google_storage_bucket_object" "source_objects" {
  for_each = var.functions
  
  name   = "${each.value.name}-${data.archive_file.source_zip[each.key].output_md5}.zip"
  bucket = google_storage_bucket.source_bucket.name
  source = data.archive_file.source_zip[each.key].output_path
}

# Zip source code
data "archive_file" "source_zip" {
  for_each = var.functions
  
  type        = "zip"
  source_dir  = each.value.source_dir
  output_path = "${path.module}/tmp/${each.value.name}.zip"
}

# HTTP trigger for HTTP functions
resource "google_cloudfunctions2_function_iam_member" "invoker" {
  for_each = {
    for k, v in var.functions : k => v
    if v.trigger_type == "http"
  }
  
  project        = var.project_id
  location       = var.region
  cloud_function = google_cloudfunctions2_function.functions[each.key].name
  role           = "roles/cloudfunctions.invoker"
  member         = "allUsers" # Change this to specific users/service accounts for production
}

# Outputs
output "function_urls" {
  description = "URLs of the deployed Cloud Functions"
  value = {
    for k, v in google_cloudfunctions2_function.functions : k => v.url
  }
}

output "function_names" {
  description = "Names of the deployed Cloud Functions"
  value = {
    for k, v in google_cloudfunctions2_function.functions : k => v.name
  }
}

output "source_bucket_name" {
  description = "Name of the source code storage bucket"
  value       = google_storage_bucket.source_bucket.name
} 