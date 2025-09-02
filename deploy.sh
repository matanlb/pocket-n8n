#!/bin/bash

# n8n Fly.io Deployment Script
# This script handles the deployment of n8n to Fly.io

set -e

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/utils.sh"

# Load configuration from config.yaml
load_config_from_yaml

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
    
    if [[ ! -f config.yaml ]]; then
        print_warning "No config.yaml file found - skipping secret check"
        return
    fi
    
    # Extract secret values from config.yaml
    local encryption_key=$(yq eval '.n8n.encryption_key' config.yaml)
    local smtp_pass=$(yq eval '.email.password // ""' config.yaml)
    
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
    
    # Collect environment variables from config.yaml
    local env_args=""
    
    if [[ -f config.yaml ]]; then
        print_status "Reading configuration from config.yaml..."
        
        # Required config values
        local webhook_url=$(yq eval '.app.webhook_url' config.yaml)
        local log_level=$(yq eval '.n8n.log_level' config.yaml)
        local timezone=$(yq eval '.n8n.timezone' config.yaml)
        
        env_args="--env WEBHOOK_URL=$webhook_url --env N8N_LOG_LEVEL=$log_level --env GENERIC_TIMEZONE=$timezone"
        
        # Optional email config (only if email section exists)
        if yq eval '.email' config.yaml > /dev/null 2>&1; then
            local email_mode=$(yq eval '.email.mode' config.yaml)
            local smtp_host=$(yq eval '.email.host' config.yaml)
            local smtp_port=$(yq eval '.email.port' config.yaml)
            local smtp_user=$(yq eval '.email.user' config.yaml)
            local smtp_sender=$(yq eval '.email.sender' config.yaml)
            
            env_args="$env_args --env N8N_EMAIL_MODE=$email_mode --env N8N_SMTP_HOST=$smtp_host --env N8N_SMTP_PORT=$smtp_port --env N8N_SMTP_USER=$smtp_user --env N8N_SMTP_SENDER=$smtp_sender"
        fi
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
