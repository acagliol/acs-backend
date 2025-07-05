# Firestore Module
# This module creates Firestore database and collections for LCP backend

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

# =============================================================================
# LCP COLLECTIONS - DEFINED DIRECTLY IN MODULE
# =============================================================================

# =============================================================================
# Example of a collection
# =============================================================================

# Collection: Conversations
# Description: Individual email messages within conversations
# Indexes:
# - organization_id: ASCENDING
# - timestamp: DESCENDING
# - associated_account: ASCENDING
# - status: ASCENDING




# Note: Single-field indexes are automatically created by Firestore
# We only need to define composite indexes for complex queries

# 3. Conversations Collection - Composite Indexes
resource "google_firestore_index" "conversations_org_time" { # This is a composite index with two fields: organization_id and timestamp
  project    = var.project_id
  collection = "conversations"

  fields {
    field_path = "organization_id" # first part of the composite index
    order      = "ASCENDING"
  }

  fields {
    field_path = "timestamp" # second part of the composite index
    order      = "DESCENDING"
  }
}

# With the composite index, we can query the collection by organization_id and timestamp in descending order





# More

resource "google_firestore_index" "conversations_account_time" {
  project    = var.project_id
  collection = "conversations"

  fields {
    field_path = "associated_account"
    order      = "ASCENDING"
  }

  fields {
    field_path = "timestamp"
    order      = "DESCENDING"
  }
}

resource "google_firestore_index" "conversations_conv_status" {
  project    = var.project_id
  collection = "conversations"

  fields {
    field_path = "conversation_id"
    order      = "ASCENDING"
  }

  fields {
    field_path = "status"
    order      = "ASCENDING"
  }
}

# 4. Threads Collection - Composite Indexes
resource "google_firestore_index" "threads_org_status" {
  project    = var.project_id
  collection = "threads"

  fields {
    field_path = "organization_id"
    order      = "ASCENDING"
  }

  fields {
    field_path = "status"
    order      = "ASCENDING"
  }

  fields {
    field_path = "last_message_at"
    order      = "DESCENDING"
  }
}

resource "google_firestore_index" "threads_account_status" {
  project    = var.project_id
  collection = "threads"

  fields {
    field_path = "associated_account"
    order      = "ASCENDING"
  }

  fields {
    field_path = "status"
    order      = "ASCENDING"
  }

  fields {
    field_path = "last_message_at"
    order      = "DESCENDING"
  }
}

resource "google_firestore_index" "threads_org_flag" {
  project    = var.project_id
  collection = "threads"

  fields {
    field_path = "organization_id"
    order      = "ASCENDING"
  }

  fields {
    field_path = "flag_for_review"
    order      = "ASCENDING"
  }

  fields {
    field_path = "last_message_at"
    order      = "DESCENDING"
  }
}


# 9. EVData Collection - Composite Indexes
resource "google_firestore_index" "ev_data_org_score" {
  project    = var.project_id
  collection = "ev_data"

  fields {
    field_path = "organization_id"
    order      = "ASCENDING"
  }

  fields {
    field_path = "ev_score"
    order      = "DESCENDING"
  }
}

resource "google_firestore_index" "ev_data_org_date" {
  project    = var.project_id
  collection = "ev_data"

  fields {
    field_path = "organization_id"
    order      = "ASCENDING"
  }

  fields {
    field_path = "calculation_date"
    order      = "DESCENDING"
  }
}

# 10. LLMData Collection - Composite Indexes
resource "google_firestore_index" "llm_data_org_model" {
  project    = var.project_id
  collection = "llm_data"

  fields {
    field_path = "organization_id"
    order      = "ASCENDING"
  }

  fields {
    field_path = "model_used"
    order      = "ASCENDING"
  }

  fields {
    field_path = "generated_at"
    order      = "DESCENDING"
  }
}

resource "google_firestore_index" "llm_data_org_function" {
  project    = var.project_id
  collection = "llm_data"

  fields {
    field_path = "organization_id"
    order      = "ASCENDING"
  }

  fields {
    field_path = "function_called"
    order      = "ASCENDING"
  }

  fields {
    field_path = "generated_at"
    order      = "DESCENDING"
  }
}

# 11. Reports Collection - Composite Indexes
resource "google_firestore_index" "reports_org_type" {
  project    = var.project_id
  collection = "reports"

  fields {
    field_path = "organization_id"
    order      = "ASCENDING"
  }

  fields {
    field_path = "report_type"
    order      = "ASCENDING"
  }

  fields {
    field_path = "generated_at"
    order      = "DESCENDING"
  }
}

resource "google_firestore_index" "reports_org_period" {
  project    = var.project_id
  collection = "reports"

  fields {
    field_path = "organization_id"
    order      = "ASCENDING"
  }

  fields {
    field_path = "report_period"
    order      = "ASCENDING"
  }

  fields {
    field_path = "period_start"
    order      = "DESCENDING"
  }
}

# 12. Invocations Collection - Composite Indexes
resource "google_firestore_index" "invocations_org_function" {
  project    = var.project_id
  collection = "invocations"

  fields {
    field_path = "organization_id"
    order      = "ASCENDING"
  }

  fields {
    field_path = "function_name"
    order      = "ASCENDING"
  }

  fields {
    field_path = "invoked_at"
    order      = "DESCENDING"
  }
}

resource "google_firestore_index" "invocations_org_status" {
  project    = var.project_id
  collection = "invocations"

  fields {
    field_path = "organization_id"
    order      = "ASCENDING"
  }

  fields {
    field_path = "status"
    order      = "ASCENDING"
  }

  fields {
    field_path = "invoked_at"
    order      = "DESCENDING"
  }
}

# =============================================================================
# FIRESTORE SECURITY RULES
# =============================================================================

# Firestore Security Rules Document
resource "google_firestore_document" "security_rules" {
  project     = var.project_id
  collection  = "_firestore_rules"
  document_id = "security_rules"

  fields = jsonencode({
    rules_version = "2"
    rules = {
      service = "cloud.firestore"
      match = {
        databases = {
          database  = "{database}"
          documents = "{document=**}"
        }
        allow = [
          {
            read_write = "if request.auth != null"
            condition  = "request.auth.uid == resource.data.user_id || resource.data.organization_id == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.organization_id"
          }
        ]
      }
    }
  })
}

# =============================================================================
# OUTPUTS
# =============================================================================

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
  value = [
    "users",
    "organizations",
    "conversations",
    "threads",
    "organization_members",
    "organization_invites",
    "sessions",
    "rate_limits",
    "ev_data",
    "llm_data",
    "reports",
    "invocations"
  ]
}

output "lcp_collections" {
  description = "LCP-specific collection configurations"
  value = {
    users = {
      description = "User account information and profiles"
      indexes     = ["email", "organization_id", "status", "created_at"]
    }
    organizations = {
      description = "Organization information and settings"
      indexes     = ["domain", "status", "created_at"]
    }
    conversations = {
      description       = "Individual email messages within conversations"
      indexes           = ["associated_account", "organization_id", "conversation_id", "timestamp", "status", "is_first_email"]
      composite_indexes = ["org_time", "account_time", "conv_status"]
    }
    threads = {
      description       = "Thread-level metadata and attributes"
      indexes           = ["associated_account", "organization_id", "status", "last_message_at", "flag_for_review", "lcp_enabled"]
      composite_indexes = ["org_status", "account_status", "org_flag"]
    }
    organization_members = {
      description = "Organization membership and roles"
      indexes     = ["user_id", "organization_id", "role", "status"]
    }
    organization_invites = {
      description = "Organization invitations"
      indexes     = ["email", "invite_token", "organization_id", "status", "expires_at"]
    }
    sessions = {
      description = "User session information with TTL"
      indexes     = ["user_id", "organization_id", "is_active", "expires_at"]
    }
    rate_limits = {
      description = "Rate limits for AI operations and API calls"
      indexes     = ["account_id", "service_type", "window_end", "blocked_until"]
    }
    ev_data = {
      description       = "Expected Value calculation data"
      indexes           = ["organization_id", "calculation_date", "ev_score", "model_used"]
      composite_indexes = ["org_score", "org_date"]
    }
    llm_data = {
      description       = "LLM interaction data for analysis"
      indexes           = ["conversation_id", "organization_id", "model_used", "generated_at", "function_called"]
      composite_indexes = ["org_model", "org_function"]
    }
    reports = {
      description       = "Aggregated reports and analytics data"
      indexes           = ["organization_id", "report_type", "report_period", "period_start", "generated_at"]
      composite_indexes = ["org_type", "org_period"]
    }
    invocations = {
      description       = "Cloud Function invocations for monitoring"
      indexes           = ["organization_id", "function_name", "invoked_at", "status", "cold_start"]
      composite_indexes = ["org_function", "org_status"]
    }
  }
} 