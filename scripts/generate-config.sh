#!/bin/bash

# Config Generation Script
# Generates config.yaml from template with auto-generated values

set -e

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Generate config.yaml from template
generate_config() {
    if [[ -f config.yaml ]]; then
        print_status "config.yaml already exists"
        return 0
    fi
    
    if [[ ! -f config.example.yaml ]]; then
        print_error "config.example.yaml template not found"
        exit 1
    fi
    
    print_status "Generating config.yaml from template..."
    
    # Get username for webhook URL
    local username
    username=$(whoami | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')
    
    # Generate encryption key
    local encryption_key
    encryption_key=$(openssl rand -base64 32)
    
    # Create config.yaml from template
    cp config.example.yaml config.yaml
    
    # Replace template values using yq
    yq eval ".app.webhook_url = \"https://${username}-pocket-n8n.fly.dev\"" -i config.yaml
    yq eval ".n8n.encryption_key = \"${encryption_key}\"" -i config.yaml
    
    print_status "Generated config.yaml with:"
    print_status "  • App name: pocket-n8n"
    print_status "  • Webhook URL: https://${username}-pocket-n8n.fly.dev"
    print_status "  • Encryption key: Auto-generated (32 bytes)"
    print_status "  • Region: fra (Frankfurt)"
    echo ""
    print_status "Next: Edit config.yaml if needed, then run your desired command"
}

# Main function
main() {
    generate_config
}

# Run main function
main "$@"