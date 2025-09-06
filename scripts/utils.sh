#!/bin/bash

# Shared utilities for n8n deployment scripts

# Configuration (will be loaded from config.yaml)
APP_NAME="pocket-n8n"
VOLUME_NAME="n8n_data"
REGION="fra"

# Load configuration from config.yaml
load_config_from_yaml() {
    if [[ -f "$CONFIG_FILE" ]]; then
        APP_NAME=$(yq eval '.app.name' "$CONFIG_FILE")
        REGION=$(yq eval '.app.region' "$CONFIG_FILE")
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

# Check cloud deployment dependencies (fly, yq)
check_production_deps() {
    local missing=()
    
    if ! command -v fly &> /dev/null; then
        missing+=("fly")
    fi
    
    if ! command -v yq &> /dev/null; then
        missing+=("yq")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "Missing dependencies: ${missing[*]}"
        echo ""
        print_status "Please install the missing tools:"
        for tool in "${missing[@]}"; do
            case $tool in
                fly) echo "  • Fly.io CLI: https://fly.io/docs/getting-started/installing-flyctl/" ;;
                yq) echo "  • yq: https://github.com/mikefarah/yq#install" ;;
            esac
        done
        echo ""
        exit 1
    fi
}

# Check local deployment dependencies (yq, docker, docker-compose)
check_local_deps() {
    local missing=()
    
    if ! command -v yq &> /dev/null; then
        missing+=("yq")
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
                yq) echo "  • yq: https://github.com/mikefarah/yq#install" ;;
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