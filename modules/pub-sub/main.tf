# Pub/Sub Module
# This module creates Pub/Sub topics and subscriptions for message queuing

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
  type = map(object({
    name = string
    kms_key_name = optional(string, "")
    message_storage_policy = optional(object({
      allowed_persistence_regions = list(string)
    }), null)
    message_retention_duration = optional(string, "604800s") # 7 days
    labels = optional(map(string), {})
  }))
  default = {}
}

variable "subscriptions" {
  description = "Map of Pub/Sub subscription configurations"
  type = map(object({
    name = string
    topic = string
    ack_deadline_seconds = optional(number, 20)
    message_retention_duration = optional(string, "604800s") # 7 days
    retain_acked_messages = optional(bool, false)
    expiration_policy = optional(object({
      ttl = string
    }), null)
    retry_policy = optional(object({
      minimum_backoff = optional(string, "10s")
      maximum_backoff = optional(string, "600s")
    }), null)
    dead_letter_policy = optional(object({
      dead_letter_topic = string
      max_delivery_attempts = number
    }), null)
    push_config = optional(object({
      push_endpoint = string
      attributes = optional(map(string), {})
      oidc_token = optional(object({
        service_account_email = string
        audience = optional(string, "")
      }), null)
    }), null)
    labels = optional(map(string), {})
  }))
  default = {}
}

# Locals
locals {
  common_labels = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "pub-sub"
  }
}

# Pub/Sub Topics
resource "google_pubsub_topic" "topics" {
  for_each = var.topics
  
  name = "${each.value.name}-${var.environment}"
  project = var.project_id
  
  kms_key_name = each.value.kms_key_name != "" ? each.value.kms_key_name : null
  
  dynamic "message_storage_policy" {
    for_each = each.value.message_storage_policy != null ? [each.value.message_storage_policy] : []
    content {
      allowed_persistence_regions = message_storage_policy.value.allowed_persistence_regions
    }
  }
  
  message_retention_duration = each.value.message_retention_duration
  
  labels = merge(local.common_labels, each.value.labels)
}

# Pub/Sub Subscriptions
resource "google_pubsub_subscription" "subscriptions" {
  for_each = var.subscriptions
  
  name = "${each.value.name}-${var.environment}"
  topic = google_pubsub_topic.topics[each.value.topic].name
  project = var.project_id
  
  ack_deadline_seconds = each.value.ack_deadline_seconds
  message_retention_duration = each.value.message_retention_duration
  retain_acked_messages = each.value.retain_acked_messages
  
  dynamic "expiration_policy" {
    for_each = each.value.expiration_policy != null ? [each.value.expiration_policy] : []
    content {
      ttl = expiration_policy.value.ttl
    }
  }
  
  dynamic "retry_policy" {
    for_each = each.value.retry_policy != null ? [each.value.retry_policy] : []
    content {
      minimum_backoff = retry_policy.value.minimum_backoff
      maximum_backoff = retry_policy.value.maximum_backoff
    }
  }
  
  dynamic "dead_letter_policy" {
    for_each = each.value.dead_letter_policy != null ? [each.value.dead_letter_policy] : []
    content {
      dead_letter_topic = google_pubsub_topic.topics[dead_letter_policy.value.dead_letter_topic].id
      max_delivery_attempts = dead_letter_policy.value.max_delivery_attempts
    }
  }
  
  dynamic "push_config" {
    for_each = each.value.push_config != null ? [each.value.push_config] : []
    content {
      push_endpoint = push_config.value.push_endpoint
      attributes = push_config.value.attributes
      
      dynamic "oidc_token" {
        for_each = push_config.value.oidc_token != null ? [push_config.value.oidc_token] : []
        content {
          service_account_email = oidc_token.value.service_account_email
          audience = oidc_token.value.audience
        }
      }
    }
  }
  
  labels = merge(local.common_labels, each.value.labels)
}

# IAM bindings for topics
resource "google_pubsub_topic_iam_member" "topic_iam" {
  for_each = {
    for k, v in var.topics : k => v
    if contains(keys(v), "iam_members")
  }
  
  project = var.project_id
  topic   = google_pubsub_topic.topics[each.key].name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${var.project_id}@appspot.gserviceaccount.com"
}

# IAM bindings for subscriptions
resource "google_pubsub_subscription_iam_member" "subscription_iam" {
  for_each = {
    for k, v in var.subscriptions : k => v
    if contains(keys(v), "iam_members")
  }
  
  project = var.project_id
  subscription = google_pubsub_subscription.subscriptions[each.key].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${var.project_id}@appspot.gserviceaccount.com"
}

# Outputs
output "topic_names" {
  description = "Names of the created Pub/Sub topics"
  value = {
    for k, v in google_pubsub_topic.topics : k => v.name
  }
}

output "topic_ids" {
  description = "IDs of the created Pub/Sub topics"
  value = {
    for k, v in google_pubsub_topic.topics : k => v.id
  }
}

output "subscription_names" {
  description = "Names of the created Pub/Sub subscriptions"
  value = {
    for k, v in google_pubsub_subscription.subscriptions : k => v.name
  }
}

output "subscription_ids" {
  description = "IDs of the created Pub/Sub subscriptions"
  value = {
    for k, v in google_pubsub_subscription.subscriptions : k => v.id
  }
} 