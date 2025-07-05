# Cloud KMS Module
# This module creates Cloud KMS keyrings and keys for encryption

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
  description = "The region to deploy Cloud KMS resources"
  type        = string
  default     = "us-central1"
}

variable "keyrings" {
  description = "Map of Cloud KMS keyring configurations"
  type = map(object({
    name = string
    description = optional(string, "")
    keys = map(object({
      name = string
      purpose = string # "ENCRYPT_DECRYPT", "ASYMMETRIC_SIGN", "ASYMMETRIC_DECRYPT"
      algorithm = optional(string, "GOOGLE_SYMMETRIC_ENCRYPTION")
      protection_level = optional(string, "SOFTWARE") # "SOFTWARE", "HSM"
      rotation_period = optional(string, "7776000s") # 90 days
      labels = optional(map(string), {})
    }))
  }))
  default = {}
}

# Locals
locals {
  common_labels = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "cloud-kms"
  }
}

# Cloud KMS Keyrings
resource "google_kms_key_ring" "keyrings" {
  for_each = var.keyrings
  
  name     = "${each.value.name}-${var.environment}"
  location = var.region
  project  = var.project_id
}

# Cloud KMS Crypto Keys
resource "google_kms_crypto_key" "keys" {
  for_each = merge([
    for keyring_key, keyring_value in var.keyrings : {
      for key_name, key_config in keyring_value.keys : "${keyring_key}-${key_name}" => merge(key_config, {
        keyring_name = keyring_value.name
      })
    }
  ]...)
  
  name     = "${each.value.name}-${var.environment}"
  key_ring = google_kms_key_ring.keyrings[each.value.keyring_name].id
  purpose  = each.value.purpose
  
  lifecycle {
    prevent_destroy = var.environment == "prod"
  }
  
  labels = merge(local.common_labels, each.value.labels)
}

# Cloud KMS Crypto Key Versions (for asymmetric keys)
resource "google_kms_crypto_key_version" "key_versions" {
  for_each = {
    for key_key, key_value in google_kms_crypto_key.keys : key_key => key_value
    if key_value.purpose == "ASYMMETRIC_SIGN" || key_value.purpose == "ASYMMETRIC_DECRYPT"
  }
  
  crypto_key = each.value.id
  algorithm  = each.value.algorithm
  protection_level = each.value.protection_level
}

# IAM bindings for Cloud KMS
resource "google_kms_key_ring_iam_member" "keyring_iam" {
  for_each = {
    for keyring_key, keyring_value in var.keyrings : keyring_key => keyring_value
    if contains(keys(keyring_value), "iam_members")
  }
  
  key_ring_id = google_kms_key_ring.keyrings[each.key].id
  role        = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member      = "serviceAccount:${var.project_id}@appspot.gserviceaccount.com"
}

# IAM bindings for Crypto Keys
resource "google_kms_crypto_key_iam_member" "key_iam" {
  for_each = {
    for key_key, key_value in google_kms_crypto_key.keys : key_key => key_value
    if contains(keys(key_value), "iam_members")
  }
  
  crypto_key_id = each.value.id
  role           = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member         = "serviceAccount:${var.project_id}@appspot.gserviceaccount.com"
}

# Outputs
output "keyring_names" {
  description = "Names of the created Cloud KMS keyrings"
  value = {
    for k, v in google_kms_key_ring.keyrings : k => v.name
  }
}

output "keyring_ids" {
  description = "IDs of the created Cloud KMS keyrings"
  value = {
    for k, v in google_kms_key_ring.keyrings : k => v.id
  }
}

output "crypto_key_names" {
  description = "Names of the created Cloud KMS crypto keys"
  value = {
    for k, v in google_kms_crypto_key.keys : k => v.name
  }
}

output "crypto_key_ids" {
  description = "IDs of the created Cloud KMS crypto keys"
  value = {
    for k, v in google_kms_crypto_key.keys : k => v.id
  }
}

output "crypto_key_versions" {
  description = "Versions of the created Cloud KMS crypto keys"
  value = {
    for k, v in google_kms_crypto_key_version.key_versions : k => v.version
  }
} 