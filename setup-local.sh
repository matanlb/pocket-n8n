#!/bin/bash

# Local n8n Development Setup Script
# This script sets up the local development environment for n8n

set -e

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/utils.sh"

# Create .env file if it doesn't exist
setup_env_file() {
    if [[ ! -f .env ]]; then
        print_status "Creating .env file from template..."
        cp .env.example .env
        print_warning "Please edit .env file and set your desired values before running the application"
    else
        print_status ".env file already exists"
    fi
}

# Build and start the local development environment
start_local() {
    print_status "Building Docker image..."
    docker-compose build
    
    print_status "Starting n8n in development mode..."
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
    echo "  start     Start the local development environment (default)"
    echo "  stop      Stop the local development environment"
    echo "  logs      Show n8n logs"
    echo "  cleanup   Stop and clean up all containers and volumes"
    echo "  help      Show this help message"
}

# Main function
main() {
    local command=${1:-start}
    
    case $command in
        start)
            print_status "Setting up local n8n development environment..."
            check_docker
            check_docker_compose
            setup_env_file
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