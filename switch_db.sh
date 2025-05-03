#!/bin/bash

# Enable debug mode
set -x

# Function to display usage
show_usage() {
    echo "Usage: $0 [local|remote]"
    echo "  local  - Switch to local database configuration"
    echo "  remote - Switch to remote database configuration"
    echo "  status - Show current database configuration"
}

# Function to check if a file exists
check_file() {
    if [ ! -f "$1" ]; then
        echo "Error: $1 does not exist"
        echo "Please create it from the template file"
        exit 1
    fi
}

# Function to switch database configuration
switch_db() {
    local target=$1
    local env_file=".env"
    local target_file=".env.$target"
    
    # Check if target configuration exists
    check_file "$target_file"
    
    echo "Switching to $target database configuration..."
    echo "Source file: $target_file"
    echo "Target file: $env_file"
    
    # Create backup of current .env if it exists
    if [ -f "$env_file" ]; then
        echo "Creating backup of current .env..."
        if ! cp "$env_file" "${env_file}.backup"; then
            echo "Error: Failed to create backup file"
            exit 1
        fi
    fi
    
    # Copy target configuration with explicit path
    echo "Copying new configuration..."
    if ! cp -f "$(pwd)/$target_file" "$(pwd)/$env_file"; then
        echo "Error: Failed to copy configuration"
        # Restore backup if it exists
        if [ -f "${env_file}.backup" ]; then
            cp "${env_file}.backup" "$env_file"
            echo "Restored previous configuration from backup"
        fi
        exit 1
    fi
    
    # Verify the copy worked
    if ! diff "$target_file" "$env_file" > /dev/null; then
        echo "Error: New configuration does not match source file"
        exit 1
    fi
    
    echo "Successfully switched to $target database configuration"
    
    # Kill existing Phoenix server if running
    echo "Stopping Phoenix server if running..."
    pkill -f "phx.server" || true
    
    # Clean up any existing beam files to ensure fresh start
    echo "Cleaning up compiled files..."
    mix clean
    
    echo "Configuration switched successfully. To apply changes, run these commands:"
    echo ""
    echo "1. Load the new environment variables:"
    echo "   source .env"
    echo ""
    echo "2. Clean and compile the project:"
    echo "   mix deps.clean --all"
    echo "   mix deps.get"
    echo "   mix compile"
    echo ""
    echo "3. Start the Phoenix server:"
    echo "   mix phx.server"
    echo ""
    echo "Or run them all at once:"
    echo 'source .env && mix deps.clean --all && mix deps.get && mix compile && mix phx.server'
    
    # Display new configuration
    echo -e "\nNew configuration:"
    echo "Main Database:"
    grep "DATABASE_URL" "$env_file" || echo "No main database configuration found"
    echo "Legacy Database:"
    grep "LEGACY_DATABASE_URL" "$env_file" || echo "No legacy database configuration found"
}

# Main script logic
case "$1" in
    "local")
        switch_db "local"
        ;;
    "remote")
        switch_db "remote"
        ;;
    "status")
        if [ -f ".env" ]; then
            echo "Current configuration:"
            echo "Main Database:"
            grep "DATABASE_URL" .env || echo "No main database configuration found"
            echo "Legacy Database:"
            grep "LEGACY_DATABASE_URL" .env || echo "No legacy database configuration found"
        else
            echo "No active configuration"
        fi
        ;;
    *)
        show_usage
        exit 1
        ;;
esac 