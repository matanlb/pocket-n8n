#!/bin/bash

# n8n Fly.io Deployment Script
# This script handles the deployment of n8n to Fly.io

set -e

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/utils.sh"

# Load configuration from .env
load_config_from_env

# Check if app exists, create if it doesn't
setup_app() {
    if fly apps list | grep -q "$APP_NAME"; then
        print_status "App '$APP_NAME' already exists"
    else
        print_status "Creating new app '$APP_NAME'..."
        fly apps create "$APP_NAME" --org personal
    fi
}

# Create volume if it doesn't exist
setup_volume() {
    if fly volumes list -a "$APP_NAME" | grep -q "$VOLUME_NAME"; then
        print_status "Volume '$VOLUME_NAME' already exists"
    else
        print_status "Creating volume '$VOLUME_NAME'..."
        fly volumes create "$VOLUME_NAME" --region "$REGION" --size 3 -a "$APP_NAME"
    fi
}

# Check and update secrets only if they differ
update_secrets_if_needed() {
    print_status "Checking if secrets need updating..."
    
    if [[ ! -f .env ]]; then
        print_warning "No .env file found - skipping secret check"
        return
    fi
    
    # Extract secret values from .env
    local encryption_key=$(grep "^N8N_ENCRYPTION_KEY=" .env | cut -d= -f2 | sed 's/^"\(.*\)"$/\1/')
    local smtp_pass=$(grep "^N8N_SMTP_PASS=" .env | cut -d= -f2 | sed 's/^"\(.*\)"$/\1/')
    
    # Calculate hash of current secret values
    local current_hash=$(echo "$encryption_key$smtp_pass" | sha256sum | cut -d' ' -f1)
    
    # Get stored hash from environment variables
    local stored_hash=$(fly config env -a "$APP_NAME" 2>/dev/null | grep "^SECRETS_HASH" | awk '{print $2}' || echo "")
    
    print_status "Current secrets hash: ${current_hash:0:8}..."
    print_status "Stored secrets hash: ${stored_hash:0:8}..."
    
    # Compare hashes
    if [[ "$current_hash" != "$stored_hash" ]]; then
        print_warning "Secrets have changed - updating (this will cause a restart)..."
        
        # Update secrets and store new hash
        fly secrets set "N8N_ENCRYPTION_KEY=$encryption_key" "N8N_SMTP_PASS=$smtp_pass" -a "$APP_NAME"
        
        # Store the new hash as env var (will be set during deploy)
        export SECRETS_HASH="$current_hash"
    else
        print_status "Secrets unchanged - skipping update"
    fi
}

# Deploy the application with environment variables
deploy_app() {
    print_status "Deploying application with configuration..."
    
    # Collect environment variables from .env file
    local env_args=""
    
    if [[ -f .env ]]; then
        print_status "Reading configuration from .env file..."
        
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ $key =~ ^#.*$ ]] && continue
            [[ -z $key ]] && continue
            
            # Remove quotes from value
            value=$(echo "$value" | sed 's/^"\(.*\)"$/\1/')
            
            case $key in
                # Non-sensitive config passed as deploy-time env vars
                WEBHOOK_URL|N8N_LOG_LEVEL|GENERIC_TIMEZONE|N8N_EMAIL_MODE|N8N_SMTP_HOST|N8N_SMTP_PORT|N8N_SMTP_USER|N8N_SMTP_SENDER)
                    print_status "Including env var: $key"
                    env_args="$env_args --env $key=$value"
                    ;;
            esac
        done < .env
    fi
    
    # Add SECRETS_HASH if it was updated
    if [[ -n "$SECRETS_HASH" ]]; then
        env_args="$env_args --env SECRETS_HASH=$SECRETS_HASH"
    fi
    
    # Deploy with all environment variables in single command
    print_status "Deploying with configuration..."
    print_status "Using app: $APP_NAME, region: $REGION"
    fly deploy --app "$APP_NAME" --primary-region "$REGION" $env_args
    
    if [[ $? -eq 0 ]]; then
        print_status "Deployment successful!"
        print_status "Your n8n instance is available at: https://$APP_NAME.fly.dev"
    else
        print_error "Deployment failed!"
        exit 1
    fi
}

# Main deployment flow
main() {
    print_status "Starting n8n deployment to Fly.io..."
    
    check_production_deps
    check_fly_auth
    setup_app
    setup_volume
    update_secrets_if_needed
    deploy_app
    
    print_status "Deployment complete!"
    echo "Visit https://$APP_NAME.fly.dev to access your n8n instance"
}

# Run main function
main "$@"
