#!/usr/bin/env python3
"""
Configuration loader utility for Terraform environment management.
This script loads environment configurations from environments/{env}.json files
and provides functions to access environment-specific settings.
"""

import json
import os
import sys
from pathlib import Path


def get_project_root():
    """Get the project root directory."""
    # Navigate up from scripts/utils to project root
    current_dir = Path(__file__).parent.parent.parent
    return current_dir


def load_config():
    """Load the environments configuration file."""
    config_file = get_project_root() / "environments" / "dev.json"
    
    if not config_file.exists():
        raise FileNotFoundError(f"Configuration file not found: {config_file}")
    
    try:
        with open(config_file, 'r') as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in configuration file: {e}")


def get_environment_config(env_name):
    """Get configuration for a specific environment."""
    config_file = get_project_root() / "environments" / f"{env_name}.json"
    
    if not config_file.exists():
        raise FileNotFoundError(f"Environment configuration file not found: {config_file}")
    
    try:
        with open(config_file, 'r') as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in environment configuration file: {e}")


def get_defaults():
    """Get default configuration values."""
    # Defaults are now defined in individual environment JSON files
    return {}


def list_environments():
    """List all available environments."""
    environments_dir = get_project_root() / "environments"
    
    if not environments_dir.exists():
        return []
    
    environments = []
    for file in environments_dir.glob("*.json"):
        environments.append(file.stem)
    
    return environments


def validate_environment(env_name):
    """Validate that an environment exists and has required fields."""
    try:
        env_config = get_environment_config(env_name)
        required_fields = ['project_id', 'project_name', 'region', 'zone']
        
        missing_fields = [field for field in required_fields if field not in env_config]
        if missing_fields:
            raise ValueError(f"Environment '{env_name}' missing required fields: {missing_fields}")
        
        return True
    except Exception as e:
        print(f"Validation failed: {e}", file=sys.stderr)
        return False


def main():
    """Main function for command-line usage."""
    if len(sys.argv) < 2:
        print("Usage: python config-loader.py <command> [environment]")
        print("Commands:")
        print("  list                    - List all environments")
        print("  get <environment>       - Get config for environment")
        print("  validate <environment>  - Validate environment config")
        print("  defaults                - Get default values")
        return 1
    
    command = sys.argv[1]
    
    try:
        if command == "list":
            environments = list_environments()
            print("Available environments:")
            for env in environments:
                print(f"  - {env}")
        
        elif command == "get":
            if len(sys.argv) < 3:
                print("Error: Environment name required for 'get' command")
                return 1
            
            env_name = sys.argv[2]
            env_config = get_environment_config(env_name)
            print(json.dumps(env_config, indent=2))
        
        elif command == "validate":
            if len(sys.argv) < 3:
                print("Error: Environment name required for 'validate' command")
                return 1
            
            env_name = sys.argv[2]
            if validate_environment(env_name):
                print(f"Environment '{env_name}' is valid")
            else:
                return 1
        
        elif command == "defaults":
            print("Default values are now defined in individual environment JSON files")
            print("Use 'get <environment>' to view specific environment configuration")
        
        else:
            print(f"Unknown command: {command}")
            return 1
    
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1
    
    return 0


if __name__ == "__main__":
    sys.exit(main()) 