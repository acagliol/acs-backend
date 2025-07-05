# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_FILE="$PROJECT_ROOT/config/environments.json"

# Function to load environment configuration
load_environment_config() {
    local env="$1"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    if command -v jq &> /dev/null; then
        local config
        config=$(jq -r ".environments.$env" "$CONFIG_FILE" 2>/dev/null)
        if [[ "$config" == "null" ]] || [[ -z "$config" ]]; then
            print_error "Environment '$env' not found in configuration file"
            exit 1
        fi
        echo "$config"
    else
        print_error "jq is required to parse the configuration file"
        print_error "Please install jq: sudo apt-get install jq (Ubuntu/Debian) or brew install jq (macOS)"
        exit 1
    fi
}

# Function to print colored output
print_status() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

print_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

print_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

print_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

# Main deployment logic
main() {
    local env="$1"
    local action="$2"
    
    if [[ -z "$env" ]] || [[ -z "$action" ]]; then
        print_error "Usage: $0 <environment> <action>"
        print_error "Environments: dev, staging, prod"
        print_error "Actions: plan, apply, destroy"
        exit 1
    fi
    
    # Load environment configuration
    local config
    config=$(load_environment_config "$env")
    
    # Set environment variables
    export TF_VAR_environment="$env"
    
    # Change to project root
    cd "$PROJECT_ROOT"
    
    # Initialize Terraform with backend configuration
    print_status "Initializing Terraform for environment: $env"
    local bucket_name
    bucket_name=$(echo "$config" | jq -r '.bucket_name' 2>/dev/null || echo "terraform-state-$env-anay")
    
    terraform init \
        -backend-config="bucket=$bucket_name" \
        -backend-config="prefix=terraform/state"
    
    if [[ $? -ne 0 ]]; then
        print_error "Terraform initialization failed"
        exit 1
    fi
    
    # Perform the requested action
    case "$action" in
        "plan")
            print_status "Planning Terraform deployment for environment: $env"
            terraform plan -var="environment=$env"
            ;;
        "apply")
            # Safety check for production
            if [[ "$env" == "prod" ]]; then
                print_warning "WARNING: You are about to deploy to PRODUCTION!"
                read -p "Type 'yes' to confirm: " confirmation
                if [[ "$confirmation" != "yes" ]]; then
                    print_warning "Deployment cancelled"
                    exit 0
                fi
            fi
            
            print_status "Applying Terraform configuration for environment: $env"
            terraform apply -var="environment=$env" -auto-approve
            ;;
        "destroy")
            # Safety check for production
            if [[ "$env" == "prod" ]]; then
                print_warning "WARNING: You are about to DESTROY PRODUCTION infrastructure!"
                read -p "Type 'DESTROY-PROD' to confirm: " confirmation
                if [[ "$confirmation" != "DESTROY-PROD" ]]; then
                    print_warning "Destruction cancelled"
                    exit 0
                fi
            fi
            
            print_status "Destroying Terraform infrastructure for environment: $env"
            terraform destroy -var="environment=$env" -auto-approve
            ;;
        *)
            print_error "Invalid action: $action"
            print_error "Valid actions: plan, apply, destroy"
            exit 1
            ;;
    esac
    
    if [[ $? -ne 0 ]]; then
        print_error "Terraform $action failed"
        exit 1
    fi
    
    print_success "Terraform $action completed successfully for environment: $env"
}

# Execute main function with arguments
main "$@" 