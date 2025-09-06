#!/bin/bash

# n8n Backup Script for Local and Cloud Deployments
# This script creates backups of n8n data and workflows

set -e

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config.yaml"
source "$SCRIPT_DIR/utils.sh"

# Load configuration from config.yaml
load_config_from_yaml

# Configuration
BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Create backup directory
create_backup_dir() {
    mkdir -p "$BACKUP_DIR"
    print_status "Backup directory created: $BACKUP_DIR"
}

# Backup n8n data from cloud deployment (zero downtime)
backup_cloud() {
    local backup_file="$BACKUP_DIR/n8n_cloud_backup_${TIMESTAMP}.tar.gz"
    
    print_status "Creating backup from cloud deployment: $APP_NAME (zero downtime)"
    
    # Create backup via SSH to running machine
    print_status "Connecting to running machine and creating backup..."
    fly ssh console -a "$APP_NAME" -C "sh -c 'cd /home/node/.n8n && tar -czf /tmp/backup_${TIMESTAMP}.tar.gz .'"
    
    # Download the backup file
    print_status "Downloading backup file..."
    fly ssh sftp get "/tmp/backup_${TIMESTAMP}.tar.gz" "$backup_file" -a "$APP_NAME"
    
    # Clean up remote backup file
    fly ssh console -a "$APP_NAME" -C "rm -f /tmp/backup_${TIMESTAMP}.tar.gz"
    
    if [[ -f "$backup_file" && -s "$backup_file" ]]; then
        print_status "Cloud backup completed successfully: $backup_file"
        print_status "Backup size: $(du -h "$backup_file" | cut -f1)"
    else
        print_error "Cloud backup failed or is empty"
        exit 1
    fi
}

# Backup n8n data from local deployment (zero downtime)
backup_local() {
    local backup_file="$BACKUP_DIR/n8n_local_backup_${TIMESTAMP}.tar.gz"
    
    print_status "Creating backup from local deployment (zero downtime)"
    
    # Check if local deployment is running
    if ! docker-compose ps | grep -q "n8n.*Up"; then
        print_error "Local n8n deployment is not running. Start it with 'make start'"
        exit 1
    fi
    
    # Create backup inside running container
    print_status "Creating backup inside container..."
    docker-compose exec -T n8n tar -czf /tmp/backup_${TIMESTAMP}.tar.gz -C /home/node/.n8n .
    
    # Copy backup out of container
    print_status "Extracting backup file..."
    local container_name=$(docker-compose ps -q n8n)
    docker cp "$container_name:/tmp/backup_${TIMESTAMP}.tar.gz" "$backup_file"
    
    # Clean up backup file inside container
    docker-compose exec -T n8n rm -f "/tmp/backup_${TIMESTAMP}.tar.gz"
    
    if [[ -f "$backup_file" && -s "$backup_file" ]]; then
        print_status "Local backup completed successfully: $backup_file"
        print_status "Backup size: $(du -h "$backup_file" | cut -f1)"
    else
        print_error "Local backup failed or is empty"
        exit 1
    fi
}

# Restore backup to cloud deployment
restore_cloud() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        print_error "Backup file not found: $backup_file"
        exit 1
    fi
    
    print_status "Restoring backup to cloud deployment: $APP_NAME"
    print_warning "This will overwrite existing data and requires brief downtime!"
    
    # Upload backup file
    print_status "Uploading backup file..."
    cat "$backup_file" | fly ssh console -a "$APP_NAME" -C "dd of=/tmp/restore_${TIMESTAMP}.tar.gz"
    
    # Stop n8n process, restore data, restart
    print_status "Stopping n8n, restoring data, and restarting..."
    fly ssh console -a "$APP_NAME" -C "sh -c 'pkill -f n8n || true && cd /home/node/.n8n && rm -rf ./* && tar -xzf /tmp/restore_${TIMESTAMP}.tar.gz && rm -f /tmp/restore_${TIMESTAMP}.tar.gz && nohup n8n > /dev/null 2>&1 &'"
    
    print_status "Cloud restore completed successfully"
    print_status "Your n8n instance should be available shortly at: https://$APP_NAME.fly.dev"
}

# Restore backup to local deployment
restore_local() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        print_error "Backup file not found: $backup_file"
        exit 1
    fi
    
    print_status "Restoring backup to local deployment"
    print_warning "This will overwrite existing data and requires brief downtime!"
    
    # Check if local deployment is running
    if ! docker-compose ps | grep -q "n8n.*Up"; then
        print_error "Local n8n deployment is not running. Start it with 'make start'"
        exit 1
    fi
    
    # Copy backup into container
    print_status "Uploading backup file to container..."
    local container_name=$(docker-compose ps -q n8n)
    docker cp "$backup_file" "$container_name:/tmp/restore_${TIMESTAMP}.tar.gz"
    
    # Stop n8n process, restore data, restart
    print_status "Stopping n8n, restoring data, and restarting..."
    docker-compose exec -T n8n sh -c "
        pkill -f n8n || true && 
        cd /home/node/.n8n && 
        rm -rf ./* && 
        tar -xzf /tmp/restore_${TIMESTAMP}.tar.gz && 
        rm -f /tmp/restore_${TIMESTAMP}.tar.gz && 
        nohup n8n > /dev/null 2>&1 &
    "
    
    print_status "Local restore completed successfully"
    print_status "Your n8n instance should be available at: http://localhost:5678"
}

# List available backups
list_backups() {
    print_status "Available backups in $BACKUP_DIR:"
    if [[ -d "$BACKUP_DIR" ]]; then
        local backups_found=false
        
        # List cloud backups
        if ls "$BACKUP_DIR"/n8n_cloud_backup_*.tar.gz >/dev/null 2>&1; then
            print_status "Cloud Backups:"
            ls -lah "$BACKUP_DIR"/n8n_cloud_backup_*.tar.gz 2>/dev/null | awk '{print "  " $5 "  " $6 " " $7 " " $8 "  " $9}'
            backups_found=true
        fi
        
        # List local backups  
        if ls "$BACKUP_DIR"/n8n_local_backup_*.tar.gz >/dev/null 2>&1; then
            print_status "Local Backups:"
            ls -lah "$BACKUP_DIR"/n8n_local_backup_*.tar.gz 2>/dev/null | awk '{print "  " $5 "  " $6 " " $7 " " $8 "  " $9}'
            backups_found=true
        fi
        
        if [[ "$backups_found" == false ]]; then
            print_warning "No backup files found"
        fi
    else
        print_warning "Backup directory does not exist"
    fi
}

# Clean old backups (keep last 5 of each type)
cleanup_backups() {
    print_status "Cleaning old backups (keeping last 5 of each type)..."
    if [[ -d "$BACKUP_DIR" ]]; then
        cd "$BACKUP_DIR"
        
        # Clean cloud backups
        if ls n8n_cloud_backup_*.tar.gz 2>/dev/null; then
            ls -t n8n_cloud_backup_*.tar.gz 2>/dev/null | tail -n +6 | xargs -r rm -f
            print_status "Cleaned old cloud backups"
        fi
        
        # Clean local backups
        if ls n8n_local_backup_*.tar.gz 2>/dev/null; then
            ls -t n8n_local_backup_*.tar.gz 2>/dev/null | tail -n +6 | xargs -r rm -f
            print_status "Cleaned old local backups"
        fi
        
        print_status "Cleanup completed"
        list_backups
    else
        print_warning "Backup directory does not exist"
    fi
}

# Show usage information
show_usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  backup-local       Create backup from local deployment (zero downtime)"
    echo "  backup-cloud       Create backup from cloud deployment (zero downtime)"
    echo "  restore-local <file>   Restore backup to local deployment (brief downtime)"
    echo "  restore-cloud <file>   Restore backup to cloud deployment (brief downtime)"
    echo "  list               List available backups"
    echo "  cleanup            Remove old backups (keep last 5 of each type)"
    echo "  help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 backup-local"
    echo "  $0 restore-local backups/n8n_local_backup_20231201_120000.tar.gz"
    echo "  $0 backup-cloud"
    echo "  $0 restore-cloud backups/n8n_cloud_backup_20231201_120000.tar.gz"
}

# Main function
main() {
    local command="$1"
    local backup_file="$2"
    
    case $command in
        backup-local)
            check_local_deps
            check_docker_running
            create_backup_dir
            backup_local
            ;;
        backup-cloud)
            check_production_deps
            check_fly_auth
            create_backup_dir
            backup_cloud
            ;;
        restore-local)
            if [[ -z "$backup_file" ]]; then
                print_error "Please specify backup file"
                show_usage
                exit 1
            fi
            check_local_deps
            check_docker_running
            restore_local "$backup_file"
            ;;
        restore-cloud)
            if [[ -z "$backup_file" ]]; then
                print_error "Please specify backup file"
                show_usage
                exit 1
            fi
            check_production_deps
            check_fly_auth
            restore_cloud "$backup_file"
            ;;
        list)
            list_backups
            ;;
        cleanup)
            cleanup_backups
            ;;
        help|"")
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