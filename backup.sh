#!/bin/bash

# n8n Backup Script for Fly.io
# This script creates backups of n8n data and workflows

set -e

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/utils.sh"

# Load configuration from .env
load_config_from_env

# Configuration
BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Create backup directory
create_backup_dir() {
    mkdir -p "$BACKUP_DIR"
    print_status "Backup directory created: $BACKUP_DIR"
}

# Backup n8n data from Fly.io (zero downtime)
backup_remote() {
    local backup_file="$BACKUP_DIR/n8n_backup_${TIMESTAMP}.tar.gz"
    
    print_status "Creating backup from Fly.io app: $APP_NAME (zero downtime)"
    
    # Create backup via SSH to running machine
    print_status "Connecting to running machine and creating backup..."
    fly ssh console -a "$APP_NAME" -C "sh -c 'cd /home/node/.n8n && tar -czf /tmp/backup_${TIMESTAMP}.tar.gz .'"
    
    # Download the backup file
    print_status "Downloading backup file..."
    fly ssh sftp get -a "$APP_NAME" "/tmp/backup_${TIMESTAMP}.tar.gz" "$backup_file"
    
    # Clean up remote backup file
    fly ssh console -a "$APP_NAME" -C "rm -f /tmp/backup_${TIMESTAMP}.tar.gz"
    
    if [[ -f "$backup_file" && -s "$backup_file" ]]; then
        print_status "Backup completed successfully: $backup_file"
        print_status "Backup size: $(du -h "$backup_file" | cut -f1)"
    else
        print_error "Backup failed or is empty"
        exit 1
    fi
}

# Restore backup to Fly.io
restore_remote() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        print_error "Backup file not found: $backup_file"
        exit 1
    fi
    
    print_status "Restoring backup to Fly.io app: $APP_NAME"
    print_warning "This will overwrite existing data and requires brief downtime!"
    read -p "Are you sure you want to continue? (y/N): " confirm
    
    if [[ $confirm != [yY] ]]; then
        print_status "Restore cancelled"
        exit 0
    fi
    
    # Upload backup file
    print_status "Uploading backup file..."
    fly ssh sftp put -a "$APP_NAME" "$backup_file" "/tmp/restore_${TIMESTAMP}.tar.gz"
    
    # Stop n8n process, restore data, restart
    print_status "Stopping n8n, restoring data, and restarting..."
    fly ssh console -a "$APP_NAME" -C "sh -c 'pkill -f n8n || true && cd /home/node/.n8n && rm -rf ./* && tar -xzf /tmp/restore_${TIMESTAMP}.tar.gz && rm -f /tmp/restore_${TIMESTAMP}.tar.gz && nohup n8n > /dev/null 2>&1 &'"
    
    print_status "Restore completed successfully"
    print_status "Your n8n instance should be available shortly at: https://$APP_NAME.fly.dev"
}

# List available backups
list_backups() {
    print_status "Available backups in $BACKUP_DIR:"
    if [[ -d "$BACKUP_DIR" ]]; then
        ls -lah "$BACKUP_DIR"/*.tar.gz 2>/dev/null || print_warning "No backup files found"
    else
        print_warning "Backup directory does not exist"
    fi
}

# Clean old backups (keep last 5)
cleanup_backups() {
    print_status "Cleaning old backups (keeping last 5)..."
    if [[ -d "$BACKUP_DIR" ]]; then
        cd "$BACKUP_DIR"
        ls -t *.tar.gz 2>/dev/null | tail -n +6 | xargs -r rm -f
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
    echo "  backup             Create backup from Fly.io (zero downtime)"
    echo "  restore <file>     Restore backup to Fly.io (brief downtime)"
    echo "  list               List available backups"
    echo "  cleanup            Remove old backups (keep last 5)"
    echo "  help               Show this help message"
}

# Main function
main() {
    local command="$1"
    local backup_file="$2"
    
    case $command in
        backup)
            check_fly_cli
            check_fly_auth
            create_backup_dir
            backup_remote
            ;;
        restore)
            if [[ -z "$backup_file" ]]; then
                print_error "Please specify backup file"
                show_usage
                exit 1
            fi
            check_fly_cli
            check_fly_auth
            restore_remote "$backup_file"
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