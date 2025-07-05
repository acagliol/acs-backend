# AI Editing Guide for Terraform Backend Infrastructure

## Overview

This guide provides instructions for AI agents (like Cursor, GitHub Copilot, etc.) working on this Terraform backend infrastructure project. Follow these guidelines to ensure code quality, security, and maintainability.

## Project Structure Rules

### Directory Organization
- **USE** a single `main.tf` file for all resource definitions
- **ORGANIZE** environment-specific settings in `environments/{env}.json` files
- **PLACE** variable declarations in `variables.tf`
- **KEEP** backend configuration in `backend.tf`
- **STORE** deployment scripts in `scripts/` directory

### File Naming Conventions
- Main configuration: `main.tf`, `variables.tf`, `backend.tf`
- Environment configurations: `environments/{environment}.json`
- Deployment scripts: `deploy.ps1`, `deploy.sh`

## Code Organization Standards

### Dynamic Environment Configuration
```hcl
# GOOD: Dynamic environment loading
locals {
  environment = var.environment != null ? var.environment : "dev"
  env_config_file = file("${path.module}/environments/${local.environment}.json")
  env_config      = jsondecode(local.env_config_file)
}

# BAD: Hardcoded environment values
locals {
  environment = "dev"
  project_id  = "my-project"
}
```

### Resource Naming
```hcl
# GOOD: Environment-aware naming
resource "google_compute_instance" "web_servers" {
  count        = local.env_config.instance_count
  name         = "web-server-${local.environment}-${count.index + 1}"
}

# BAD: Generic naming
resource "google_compute_instance" "instance" {
  name = "instance"
}
```

### Variable Definitions
```hcl
# GOOD: Well-documented variables with validation
variable "environment" {
  description = "Environment to deploy (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# BAD: Undocumented variables
variable "env" {
  type = string
}
```

### Output Definitions
```hcl
# GOOD: Descriptive outputs with documentation
output "instance_external_ips" {
  description = "External IP addresses of the compute instances"
  value       = google_compute_instance.web_servers[*].network_interface[0].access_config[0].nat_ip
}

# BAD: Generic outputs
output "ips" {
  value = google_compute_instance.instance.network_interface[0].access_config[0].nat_ip
}
```

## Environment Configuration Standards

### JSON Configuration Structure
```json
{
  "environment": "dev",
  "project_id": "terraform-anay-dev",
  "bucket_name": "terraform-state-dev-anay",
  "region": "us-central1",
  "zone": "us-central1-c",
  "machine_type": "e2-micro",
  "subnet_cidr": "10.0.1.0/24",
  "disk_size": 20,
  "instance_count": 1,
  "enable_monitoring": false,
  "enable_backup": false
}
```

### Environment-Specific Features
```hcl
# GOOD: Conditional resource creation based on environment
resource "google_compute_forwarding_rule" "load_balancer" {
  count   = local.environment != "dev" ? 1 : 0
  name    = "lb-${local.environment}"
  region  = local.env_config.region
  target  = google_compute_target_pool.web_pool[0].self_link
}

# BAD: Always create all resources
resource "google_compute_forwarding_rule" "load_balancer" {
  name    = "lb-${local.environment}"
  region  = local.env_config.region
  target  = google_compute_target_pool.web_pool.self_link
}
```

## Security Best Practices

### IAM and Access Control
```hcl
# GOOD: Principle of least privilege
resource "google_project_iam_member" "developer_role" {
  project = local.env_config.project_id
  role    = "roles/compute.developer"
  member  = "user:developer@company.com"
}

# BAD: Overly permissive access
resource "google_project_iam_member" "admin_role" {
  project = local.env_config.project_id
  role    = "roles/owner"
  member  = "user:developer@company.com"
}
```

### Network Security
```hcl
# GOOD: Environment-specific firewall rules
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh-${local.environment}"
  network = google_compute_network.vpc.name
  
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  
  source_ranges = local.environment == "prod" ? var.allowed_ssh_ips : ["0.0.0.0/0"]
  target_tags   = ["ssh"]
}

# BAD: Open firewall rules
resource "google_compute_firewall" "allow_all" {
  name    = "allow-all"
  network = google_compute_network.vpc.name
  
  allow {
    protocol = "all"
  }
  
  source_ranges = ["0.0.0.0/0"]
}
```

### Production Protection
```hcl
# GOOD: Lifecycle rules for production protection
resource "google_compute_instance" "web_servers" {
  # ... configuration
  
  lifecycle {
    prevent_destroy = local.environment == "prod"
  }
}

# BAD: No protection for production resources
resource "google_compute_instance" "web_servers" {
  # ... configuration
}
```

## Environment-Specific Guidelines

### Development Environment
- **ALLOW** rapid iteration and experimentation
- **USE** smaller instance types for cost efficiency
- **ENABLE** detailed logging and debugging
- **PERMIT** direct developer access for testing
- **SKIP** advanced features (load balancers, monitoring)

### Staging Environment
- **MIRROR** production configuration as closely as possible
- **REQUIRE** pull request approval for changes
- **ENABLE** automated testing and validation
- **USE** production-like data volumes
- **INCLUDE** monitoring and backup features

### Production Environment
- **NEVER** make direct changes to production code
- **ALWAYS** test changes in staging first
- **REQUIRE** admin approval for all changes
- **MAINTAIN** strict change control procedures
- **ENABLE** all security and monitoring features

## Deployment Guidelines

### Dynamic Deployment Script
```powershell
# GOOD: Dynamic environment loading
$ConfigFile = Join-Path $ProjectRoot "environments\$Environment.json"
$Config = Get-Content $ConfigFile | ConvertFrom-Json

# Set environment variables
$env:TF_VAR_environment = $Environment

# Initialize with backend configuration
$BackendConfig = @(
    "-backend-config=bucket=$($Config.bucket_name)",
    "-backend-config=prefix=terraform/state"
)
terraform init @BackendConfig
```

### Pre-Deployment Checklist
1. ✅ Run `terraform fmt` to format code
2. ✅ Run `terraform validate` to check syntax
3. ✅ Run `terraform plan` to review changes
4. ✅ Test in staging environment first
5. ✅ Get approval for production changes
6. ✅ Backup current state
7. ✅ Notify team of deployment

### Post-Deployment Verification
1. ✅ Verify all resources are created correctly
2. ✅ Check application functionality
3. ✅ Monitor resource utilization
4. ✅ Validate security configurations
5. ✅ Update documentation if needed

## Future-Proofing Guidelines

### Version Constraints
```hcl
# GOOD: Specific version constraints
terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

# BAD: No version constraints
terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}
```

### Data Source Usage
```hcl
# GOOD: Use data sources for dynamic values
data "google_compute_image" "cos" {
  family  = "cos-stable"
  project = "cos-cloud"
}

resource "google_compute_instance" "instance" {
  # ...
  boot_disk {
    initialize_params {
      image = data.google_compute_image.cos.self_link
    }
  }
}

# BAD: Hardcoded image references
resource "google_compute_instance" "instance" {
  # ...
  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
    }
  }
}
```

## Common Patterns

### Environment-Specific Configuration
```hcl
locals {
  # Environment-specific configurations loaded from JSON
  env_config = jsondecode(file("${path.module}/environments/${var.environment}.json"))
  
  # Common tags for all resources
  common_tags = {
    Environment = var.environment
    Project     = local.env_config.project_id
    ManagedBy   = "terraform"
    Owner       = "infrastructure-team"
    CostCenter  = "engineering"
  }
}
```

### Conditional Resource Creation
```hcl
# Load balancer (only for staging and production)
resource "google_compute_forwarding_rule" "load_balancer" {
  count   = local.environment != "dev" ? 1 : 0
  name    = "lb-${local.environment}"
  region  = local.env_config.region
  target  = google_compute_target_pool.web_pool[0].self_link
}

# Monitoring (only when enabled in config)
resource "google_monitoring_uptime_check_config" "web_uptime" {
  count        = local.env_config.enable_monitoring ? 1 : 0
  display_name = "Web Server Uptime Check - ${local.environment}"
  # ... configuration
}
```

## Error Prevention

### Common Mistakes to Avoid
1. **NEVER** hardcode project IDs or region names in main.tf
2. **NEVER** use `terraform destroy` without explicit confirmation
3. **NEVER** commit sensitive information to version control
4. **NEVER** skip testing in staging before production
5. **NEVER** use generic resource names
6. **NEVER** ignore Terraform plan output
7. **NEVER** make production changes without approval
8. **NEVER** modify environment JSON files without validation

### Safety Checks
```hcl
# GOOD: Safety checks for destructive operations
resource "google_compute_instance" "critical_server" {
  # ... configuration
  
  lifecycle {
    prevent_destroy = var.environment == "prod"
  }
}

# GOOD: Backup before deletion
resource "google_compute_disk" "data_disk" {
  # ... configuration
  
  lifecycle {
    create_before_destroy = true
  }
}
```

## Testing Guidelines

### Unit Testing
- Write tests for all modules
- Test with different variable combinations
- Validate outputs match expectations
- Test error conditions

### Integration Testing
- Test complete environment deployments
- Validate cross-resource dependencies
- Test rollback procedures
- Verify security configurations

## AI-Specific Instructions

### When Creating New Resources
1. **ALWAYS** check existing resources first
2. **ALWAYS** use environment-specific naming
3. **ALWAYS** add proper documentation
4. **ALWAYS** include validation rules
5. **ALWAYS** consider security implications
6. **ALWAYS** make resources conditional when appropriate

### When Modifying Existing Resources
1. **ALWAYS** understand the current configuration
2. **ALWAYS** test changes in dev first
3. **ALWAYS** maintain backward compatibility
4. **ALWAYS** update documentation
5. **ALWAYS** consider impact on other resources

### When Suggesting Changes
1. **ALWAYS** explain the reasoning behind changes
2. **ALWAYS** provide alternatives when possible
3. **ALWAYS** consider cost implications
4. **ALWAYS** think about long-term maintainability
5. **ALWAYS** suggest security improvements

## Conclusion

Following these guidelines ensures that all AI-assisted development maintains the highest standards of quality, security, and maintainability. The single configuration approach with dynamic environment loading provides flexibility while maintaining consistency across environments.

When in doubt, prioritize:
1. **Security** over convenience
2. **Maintainability** over cleverness
3. **Documentation** over brevity
4. **Testing** over speed
5. **Standards** over shortcuts 