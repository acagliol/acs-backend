# Monitoring Module
# This module creates Cloud Logging and Monitoring resources

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
  type = object({
    enable_logging = optional(bool, true)
    enable_monitoring = optional(bool, true)
    log_sinks = optional(map(object({
      name = string
      destination = string
      filter = optional(string, "")
      unique_writer_identity = optional(bool, true)
    })), {})
    uptime_checks = optional(map(object({
      display_name = string
      timeout = optional(string, "10s")
      period = optional(string, "60s")
      http_check = optional(object({
        path = optional(string, "/")
        port = optional(number, 80)
        use_ssl = optional(bool, false)
        validate_ssl = optional(bool, true)
        headers = optional(map(string), {})
      }), {})
      tcp_check = optional(object({
        port = number
      }), null)
    })), {})
    alerting_policies = optional(map(object({
      display_name = string
      combiner = optional(string, "OR")
      conditions = list(object({
        display_name = string
        condition_threshold = object({
          filter = string
          duration = string
          comparison = string
          threshold_value = number
          aggregations = optional(list(object({
            alignment_period = optional(string, "60s")
            per_series_aligner = optional(string, "ALIGN_RATE")
            cross_series_reducer = optional(string, "REDUCE_MEAN")
            group_by_fields = optional(list(string), [])
          })), [])
        })
      }))
      notification_channels = optional(list(string), [])
    })), {})
  })
  default = {}
}

# Locals
locals {
  common_labels = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "monitoring"
  }
}

# Log Sinks
resource "google_logging_project_sink" "log_sinks" {
  for_each = var.monitoring_config.log_sinks
  
  name        = "${each.value.name}-${var.environment}"
  destination = each.value.destination
  filter      = each.value.filter
  project     = var.project_id
  
  unique_writer_identity = each.value.unique_writer_identity
}

# Uptime Checks
resource "google_monitoring_uptime_check_config" "uptime_checks" {
  for_each = var.monitoring_config.uptime_checks
  
  display_name = "${each.value.display_name} - ${title(var.environment)}"
  timeout      = each.value.timeout
  period       = each.value.period
  project      = var.project_id
  
  dynamic "http_check" {
    for_each = each.value.http_check != null ? [each.value.http_check] : []
    content {
      path         = http_check.value.path
      port         = http_check.value.port
      use_ssl      = http_check.value.use_ssl
      validate_ssl = http_check.value.validate_ssl
      headers      = http_check.value.headers
    }
  }
  
  dynamic "tcp_check" {
    for_each = each.value.tcp_check != null ? [each.value.tcp_check] : []
    content {
      port = tcp_check.value.port
    }
  }
}

# Notification Channels
resource "google_monitoring_notification_channel" "notification_channels" {
  for_each = {
    for policy_key, policy_value in var.monitoring_config.alerting_policies : policy_key => policy_value
    if length(policy_value.notification_channels) > 0
  }
  
  display_name = "Email Notification - ${title(var.environment)}"
  type         = "email"
  project      = var.project_id
  
  labels = {
    email_address = "admin@company.com" # Replace with actual email
  }
}

# Alerting Policies
resource "google_monitoring_alert_policy" "alert_policies" {
  for_each = var.monitoring_config.alerting_policies
  
  display_name = "${each.value.display_name} - ${title(var.environment)}"
  combiner     = each.value.combiner
  project      = var.project_id
  
  dynamic "conditions" {
    for_each = each.value.conditions
    content {
      display_name = conditions.value.display_name
      
      condition_threshold {
        filter          = conditions.value.condition_threshold.filter
        duration        = conditions.value.condition_threshold.duration
        comparison      = conditions.value.condition_threshold.comparison
        threshold_value = conditions.value.condition_threshold.threshold_value
        
        dynamic "aggregations" {
          for_each = conditions.value.condition_threshold.aggregations
          content {
            alignment_period     = aggregations.value.alignment_period
            per_series_aligner   = aggregations.value.per_series_aligner
            cross_series_reducer = aggregations.value.cross_series_reducer
            group_by_fields      = aggregations.value.group_by_fields
          }
        }
      }
    }
  }
  
  dynamic "notification_channels" {
    for_each = each.value.notification_channels
    content {
      name = google_monitoring_notification_channel.notification_channels[each.key].name
    }
  }
}

# Service Account for Monitoring
resource "google_service_account" "monitoring_sa" {
  account_id   = "monitoring-sa-${var.environment}"
  display_name = "Monitoring Service Account for ${var.environment}"
  project      = var.project_id
}

# IAM bindings for Monitoring
resource "google_project_iam_member" "monitoring_iam" {
  project = var.project_id
  role    = "roles/monitoring.admin"
  member  = "serviceAccount:${google_service_account.monitoring_sa.email}"
}

resource "google_project_iam_member" "logging_iam" {
  project = var.project_id
  role    = "roles/logging.admin"
  member  = "serviceAccount:${google_service_account.monitoring_sa.email}"
}

# Outputs
output "log_sink_names" {
  description = "Names of the created log sinks"
  value = {
    for k, v in google_logging_project_sink.log_sinks : k => v.name
  }
}

output "uptime_check_names" {
  description = "Names of the created uptime checks"
  value = {
    for k, v in google_monitoring_uptime_check_config.uptime_checks : k => v.display_name
  }
}

output "alert_policy_names" {
  description = "Names of the created alert policies"
  value = {
    for k, v in google_monitoring_alert_policy.alert_policies : k => v.display_name
  }
}

output "notification_channel_names" {
  description = "Names of the created notification channels"
  value = {
    for k, v in google_monitoring_notification_channel.notification_channels : k => v.display_name
  }
}

output "service_account_email" {
  description = "The email of the monitoring service account"
  value       = google_service_account.monitoring_sa.email
} 