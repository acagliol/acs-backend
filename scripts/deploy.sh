#!/bin/bash
# =============================================================================
# UNIFIED DEPLOYMENT SCRIPT
# =============================================================================
# This script deploys to any environment (dev, staging, prod)
# Usage: ./scripts/deploy.sh dev|staging|prod

# Check if environment argument is provided
if [ $# -eq 0 ]; then
    echo "❌ Error: Environment argument required"
    echo "Usage: $0 dev|staging|prod"
    exit 1
fi

ENVIRONMENT=$1

# Validate environment argument
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo "❌ Error: Invalid environment. Must be dev, staging, or prod"
    exit 1
fi

# Environment configuration
case $ENVIRONMENT in
    "dev")
        PROJECT="acs-dev-464702"
        BACKEND_FILE="config/backend-dev.tf"
        VARS_FILE="config/dev.tfvars"
        COLOR="\033[32m"
        ;;
    "staging")
        PROJECT="acs-staging-464702"
        BACKEND_FILE="config/backend-staging.tf"
        VARS_FILE="config/staging.tfvars"
        COLOR="\033[33m"
        ;;
    "prod")
        PROJECT="acs-prod-464702"
        BACKEND_FILE="config/backend-prod.tf"
        VARS_FILE="config/prod.tfvars"
        COLOR="\033[31m"
        ;;
esac

echo -e "${COLOR}🚀 Deploying to $ENVIRONMENT Environment...\033[0m"

# Set the correct project
echo "Setting GCP project to $PROJECT..."
gcloud config set project $PROJECT

# Copy the backend configuration
echo "Setting up $ENVIRONMENT backend configuration..."
cp $BACKEND_FILE backend.tf

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Validate configuration
echo "Validating configuration..."
terraform validate

# Plan deployment
echo "Planning deployment..."
terraform plan -var-file=$VARS_FILE

# Apply changes
echo "Applying changes..."
terraform apply -var-file=$VARS_FILE

echo -e "${COLOR}✅ $ENVIRONMENT deployment completed!\033[0m" 