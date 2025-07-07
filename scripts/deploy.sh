#!/bin/bash

# =============================================================================
# SIMPLIFIED DEPLOYMENT SCRIPT (Linux/Mac)
# =============================================================================
# This script deploys to any environment using the consolidated main.tf
# Usage: ./deploy.sh dev|staging|prod

set -e  # Exit on any error

# Check if environment parameter is provided
if [ $# -eq 0 ]; then
    echo "Error: Environment parameter required"
    echo "Usage: ./deploy.sh dev|staging|prod"
    exit 1
fi

ENVIRONMENT=$1

# Validate environment parameter
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo "Error: Invalid environment. Must be dev, staging, or prod"
    exit 1
fi

# Environment configuration
case $ENVIRONMENT in
    "dev")
        PROJECT="acs-dev-464702"
        BACKEND_FILE="config/backend-dev.tf"
        COLOR="\033[32m"  # Green
        REQUIRE_CONFIRMATION=false
        ;;
    "staging")
        PROJECT="acs-staging-464702"
        BACKEND_FILE="config/backend-staging.tf"
        COLOR="\033[33m"  # Yellow
        REQUIRE_CONFIRMATION=true
        ;;
    "prod")
        PROJECT="acs-prod-464702"
        BACKEND_FILE="config/backend-prod.tf"
        COLOR="\033[31m"  # Red
        REQUIRE_CONFIRMATION=true
        ;;
esac

RESET="\033[0m"

echo -e "${COLOR}Deploying to $ENVIRONMENT Environment...${RESET}"

# Production safety check
if [ "$REQUIRE_CONFIRMATION" = true ]; then
    echo -e "${COLOR}This will deploy to $ENVIRONMENT environment${RESET}"
    read -p "Are you sure you want to continue? (yes/no): " confirmation
    if [ "$confirmation" != "yes" ]; then
        echo "Deployment cancelled by user."
        exit 1
    fi
fi

# Check if we're in the correct directory
if [ ! -f "main.tf" ]; then
    # Try going up one level if we're in the scripts directory
    if [ -f "../main.tf" ]; then
        cd ..
    else
        echo "Error: main.tf not found. Please run this script from the project root directory."
        exit 1
    fi
fi

# Check if environment configuration exists
ENV_CONFIG_PATH="environments/$ENVIRONMENT.json"
if [ ! -f "$ENV_CONFIG_PATH" ]; then
    echo "Error: Environment configuration file not found: $ENV_CONFIG_PATH"
    exit 1
fi

# Check if backend configuration exists
if [ ! -f "$BACKEND_FILE" ]; then
    echo "Error: Backend configuration file not found: $BACKEND_FILE"
    exit 1
fi

# Set the correct project
echo -e "\033[33mSetting GCP project to $PROJECT...${RESET}"
if ! gcloud config set project "$PROJECT"; then
    echo "Error: Failed to set GCP project"
    echo "Make sure gcloud is installed and you're authenticated: gcloud auth login"
    exit 1
fi

# Copy the backend configuration
echo -e "\033[33mSetting up $ENVIRONMENT backend configuration...${RESET}"
if ! cp "$BACKEND_FILE" "backend.tf"; then
    echo "Error: Failed to copy backend configuration"
    exit 1
fi

# Initialize Terraform
echo -e "\033[33mInitializing Terraform...${RESET}"
if ! terraform init; then
    echo "Error: Terraform initialization failed"
    exit 1
fi

# Format and validate configuration
echo -e "\033[33mFormatting and validating configuration...${RESET}"
if ! terraform fmt; then
    echo "Error: Terraform formatting failed"
    exit 1
fi

if ! terraform validate; then
    echo "Error: Terraform validation failed"
    exit 1
fi

# Plan deployment
echo -e "\033[33mPlanning deployment...${RESET}"
if ! terraform plan -var="environment=$ENVIRONMENT" -out=tfplan; then
    echo "Error: Terraform plan failed"
    exit 1
fi

# Create state backup before applying
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
USERNAME=$(whoami)
BACKUP_DIR="backups/$ENVIRONMENT/$TIMESTAMP-$USERNAME"
BACKUP_FILE="$BACKUP_DIR/terraform.tfstate.backup.$TIMESTAMP"

echo -e "\033[33mCreating state backup...${RESET}"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Create backup manifest
TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
cat > "$BACKUP_DIR/backup_manifest.$TIMESTAMP.json" << EOF
{
  "timestamp": "$TIMESTAMP",
  "environment": "$ENVIRONMENT",
  "username": "$USERNAME",
  "backup_file": "$BACKUP_FILE",
  "terraform_version": "$TERRAFORM_VERSION",
  "project": "$PROJECT"
}
EOF

# Pull current state and save as backup
if terraform state pull > "$BACKUP_FILE"; then
    echo -e "\033[32mState backup created: $BACKUP_FILE${RESET}"
else
    echo -e "\033[31mError creating state backup${RESET}"
    echo -e "\033[33mContinuing without backup (not recommended for production)${RESET}"
fi

# Apply changes
echo -e "\033[33mApplying changes...${RESET}"
if terraform apply tfplan; then
    # Success - clean up plan file
    if [ -f "tfplan" ]; then
        rm tfplan
    fi
    
    echo -e "${COLOR}$ENVIRONMENT deployment completed successfully!${RESET}"
    echo -e "\033[36mRun 'terraform output' to see deployment results.${RESET}"
else
    echo -e "\033[31mError: Terraform apply failed${RESET}"
    
    # Attempt rollback if backup exists
    if [ -f "$BACKUP_FILE" ]; then
        echo -e "\033[33mAttempting to rollback to previous state...${RESET}"
        if terraform state push < "$BACKUP_FILE"; then
            echo -e "\033[32mRollback successful! State restored to backup from $TIMESTAMP${RESET}"
            echo -e "\033[36mBackup location: $BACKUP_FILE${RESET}"
        else
            echo -e "\033[31mRollback failed! Manual intervention required.${RESET}"
            echo -e "\033[36mBackup state available at: $BACKUP_FILE${RESET}"
            echo -e "\033[33mYou may need to manually restore the state or destroy/recreate resources.${RESET}"
        fi
    else
        echo -e "\033[31mNo backup available for rollback. Manual intervention required.${RESET}"
    fi
    
    # Clean up plan file
    if [ -f "tfplan" ]; then
        rm tfplan
    fi
    
    exit 1
fi 