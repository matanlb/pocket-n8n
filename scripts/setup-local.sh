#!/bin/bash

# Local n8n Deployment Setup Script
# This script sets up the local deployment environment for n8n

set -e

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config.yaml"
source "$SCRIPT_DIR/utils.sh"

# Load configuration from config.yaml
load_config_from_yaml

# Check if config.yaml exists
check_config_file() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "config.yaml not found. Please run 'make setup-local' first"
        exit 1
    else
        print_status "config.yaml found"
    fi
}

# Build and start the local deployment environment
start_local() {
    print_status "Building Docker image..."
    docker-compose build
    
    print_status "Starting n8n in local mode..."
    docker-compose up -d
    
    # Wait for n8n to be ready
    print_status "Waiting for n8n to be ready..."
    sleep 10
    
    # Check if n8n is responding
    if curl -s http://localhost:5678 > /dev/null; then
        print_status "n8n is running successfully!"
        print_status "Access your local n8n instance at: http://localhost:5678"
    else
        print_warning "n8n might still be starting up. Please check the logs with:"
        echo "docker-compose logs n8n"
    fi
}

# Show logs
show_logs() {
    print_status "Showing n8n logs..."
    docker-compose logs -f n8n
}

# Stop local environment
stop_local() {
    print_status "Stopping local n8n environment..."
    docker-compose down
}

# Clean up local environment
cleanup_local() {
    print_status "Cleaning up local environment..."
    docker-compose down -v
    docker system prune -f
    print_status "Cleanup complete"
}

# Show usage information
show_usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start     Start the local deployment environment (default)"
    echo "  stop      Stop the local deployment environment"
    echo "  logs      Show n8n logs"
    echo "  cleanup   Stop and clean up all containers and volumes"
    echo "  help      Show this help message"
}

# Main function
main() {
    local command=${1:-start}
    
    case $command in
        start)
            print_status "Setting up local n8n deployment environment..."
            check_local_deps
            check_docker_running
            check_config_file
            start_local
            ;;
        stop)
            stop_local
            ;;
        logs)
            show_logs
            ;;
        cleanup)
            cleanup_local
            ;;
        help)
            show_usage
            ;;
        *)
            print_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"