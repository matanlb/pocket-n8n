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

# Check production dependencies (fly, jq, docker)
check_production_deps() {
    local missing=()
    
    if ! command -v fly &> /dev/null; then
        missing+=("fly")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi
    
    if ! command -v docker &> /dev/null; then
        missing+=("docker")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "Missing dependencies: ${missing[*]}"
        echo ""
        print_status "Please install the missing tools:"
        for tool in "${missing[@]}"; do
            case $tool in
                fly) echo "  • Fly.io CLI: https://fly.io/docs/getting-started/installing-flyctl/" ;;
                jq) echo "  • jq: https://jqlang.github.io/jq/download/" ;;
                docker) echo "  • Docker: https://docs.docker.com/get-docker/" ;;
            esac
        done
        echo ""
        exit 1
    fi
}

# Check local development dependencies (jq, docker, docker-compose)
check_local_deps() {
    local missing=()
    
    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi
    
    if ! command -v docker &> /dev/null; then
        missing+=("docker")
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        missing+=("docker-compose")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "Missing dependencies: ${missing[*]}"
        echo ""
        print_status "Please install the missing tools:"
        for tool in "${missing[@]}"; do
            case $tool in
                jq) echo "  • jq: https://jqlang.github.io/jq/download/" ;;
                docker) echo "  • Docker: https://docs.docker.com/get-docker/" ;;
                docker-compose) echo "  • Docker Compose: https://docs.docker.com/compose/install/" ;;
            esac
        done
        echo ""
        exit 1
    fi
}

# Check if user is logged in to Fly.io
check_fly_auth() {
    if ! fly auth whoami &> /dev/null; then
        print_error "Not logged in to Fly.io. Please run: fly auth login"
        exit 1
    fi
    print_status "Authenticated with Fly.io"
}

# Check if Docker is running (assumes docker is installed)
check_docker_running() {
    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker."
        exit 1
    fi
}