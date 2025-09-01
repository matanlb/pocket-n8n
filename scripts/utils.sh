#!/bin/bash

# Shared utilities for n8n deployment scripts

# Configuration (will be overridden from .env if available)
APP_NAME="pocket-n8n"
VOLUME_NAME="n8n_data"
REGION="fra"

# Load configuration from .env if available
load_config_from_env() {
    if [[ -f .env ]]; then
        # Load APP_NAME from .env
        local env_app_name=$(grep "^APP_NAME=" .env | cut -d= -f2 | sed 's/^"\(.*\)"$/\1/')
        if [[ -n "$env_app_name" ]]; then
            APP_NAME="$env_app_name"
        fi
        
        # Load FLY_REGION from .env
        local env_region=$(grep "^FLY_REGION=" .env | cut -d= -f2 | sed 's/^"\(.*\)"$/\1/')
        if [[ -n "$env_region" ]]; then
            REGION="$env_region"
        fi
    fi
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if fly CLI is installed
check_fly_cli() {
    if ! command -v fly &> /dev/null; then
        print_error "Fly CLI not found. Please install it first:"
        echo "curl -L https://fly.io/install.sh | sh"
        exit 1
    fi
    print_status "Fly CLI found"
}

# Check if user is logged in to Fly.io
check_fly_auth() {
    if ! fly auth whoami &> /dev/null; then
        print_error "Not logged in to Fly.io. Please run: fly auth login"
        exit 1
    fi
    print_status "Authenticated with Fly.io"
}

# Check if Docker is installed and running
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker not found. Please install Docker first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker."
        exit 1
    fi
    
    print_status "Docker is installed and running"
}

# Check if Docker Compose is available
check_docker_compose() {
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose not found. Please install Docker Compose."
        exit 1
    fi
    print_status "Docker Compose is available"
}