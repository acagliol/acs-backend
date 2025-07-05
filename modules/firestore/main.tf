# Firestore Module
# This module creates Firestore database and collections

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

variable "database_id" {
  description = "The ID of the Firestore database"
  type        = string
  default     = "(default)"
}

variable "location_id" {
  description = "The location of the Firestore database"
  type        = string
  default     = "us-central1"
}

variable "database_type" {
  description = "The type of the Firestore database (FIRESTORE_NATIVE or DATASTORE_MODE)"
  type        = string
  default     = "FIRESTORE_NATIVE"
  
  validation {
    condition     = contains(["FIRESTORE_NATIVE", "DATASTORE_MODE"], var.database_type)
    error_message = "Database type must be either FIRESTORE_NATIVE or DATASTORE_MODE."
  }
}

variable "collections" {
  description = "Map of collection configurations"
  type = map(object({
    name = string
    fields = map(object({
      type = string
      mode = optional(string, "NULLABLE")
    }))
  }))
  default = {}
}

# Locals
locals {
  common_labels = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "firestore"
  }
}

# Firestore Database
resource "google_firestore_database" "database" {
  project     = var.project_id
  name        = var.database_id
  location_id = var.location_id
  type        = var.database_type
}

# Firestore Collections (using Firestore indexes)
resource "google_firestore_index" "collection_indexes" {
  for_each = var.collections
  
  project = var.project_id
  collection = each.value.name
  
  dynamic "fields" {
    for_each = each.value.fields
    content {
      field_path = fields.key
      order      = "ASCENDING"
    }
  }
}

# Outputs
output "database_name" {
  description = "The name of the Firestore database"
  value       = google_firestore_database.database.name
}

output "database_id" {
  description = "The ID of the Firestore database"
  value       = google_firestore_database.database.id
}

output "database_location" {
  description = "The location of the Firestore database"
  value       = google_firestore_database.database.location_id
}

output "collection_names" {
  description = "List of collection names"
  value       = keys(var.collections)
} 