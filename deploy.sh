#!/bin/bash

# n8n Fly.io Deployment Script
# This script handles the deployment of n8n to Fly.io

set -e

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/utils.sh"

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

# Set secrets and environment variables
setup_secrets() {
    print_status "Setting up secrets and environment variables..."
    
    # Check if .env file exists
    if [[ -f .env ]]; then
        print_status "Found .env file, reading configuration..."
        
        # Read and set variables from .env file
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ $key =~ ^#.*$ ]] && continue
            [[ -z $key ]] && continue
            
            # Remove quotes from value
            value=$(echo "$value" | sed 's/^"\(.*\)"$/\1/')
            
            case $key in
                # All environment variables in Fly.io are set as secrets
                N8N_BASIC_AUTH_USER|N8N_BASIC_AUTH_PASSWORD|N8N_ENCRYPTION_KEY|WEBHOOK_URL|N8N_LOG_LEVEL|GENERIC_TIMEZONE)
                    print_status "Setting secret: $key"
                    fly secrets set "$key=$value" -a "$APP_NAME"
                    ;;
            esac
        done < .env
    else
        print_warning "No .env file found. You'll need to set configuration manually:"
        echo "# All configuration is set via secrets:"
        echo "fly secrets set N8N_BASIC_AUTH_USER=<username> -a $APP_NAME"
        echo "fly secrets set N8N_BASIC_AUTH_PASSWORD=<password> -a $APP_NAME"
        echo "fly secrets set N8N_ENCRYPTION_KEY=<encryption-key> -a $APP_NAME"
        echo "fly secrets set WEBHOOK_URL=https://$APP_NAME.fly.dev -a $APP_NAME"
        echo "fly secrets set N8N_LOG_LEVEL=info -a $APP_NAME"
    fi
}

# Deploy the application
deploy_app() {
    print_status "Deploying application..."
    fly deploy -a "$APP_NAME"
    
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
    
    check_fly_cli
    check_fly_auth
    setup_app
    setup_volume
    setup_secrets
    deploy_app
    
    print_status "Deployment complete!"
    print_status "Next steps:"
    echo "1. Visit https://$APP_NAME.fly.dev to access your n8n instance"
    echo "2. Log in with your basic auth credentials"
    echo "3. Start creating workflows!"
}

# Run main function
main "$@"