# n8n Dual Deployment Makefile
# Provides convenient shortcuts for both local and cloud deployments

.PHONY: help setup setup-local start stop logs-local restart clean shell build pull backup-local restore-local local-upgrade reset deploy backup-cloud restore-cloud status ssh logs-cloud logs-cloud-follow resume suspend machine-list secrets-list env-list auth whoami production-deploy list-backups cleanup-backups check-deps config

# Default target
help: ## Show this help message
	@echo "n8n Dual Deployment - Available Commands:"
	@echo ""
	@echo "📋 SETUP COMMANDS"
	@grep -E '^[a-zA-Z_-]+:.*?## .*Setup.*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {gsub(/^Setup - /, "", $$2); printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "☁️  CLOUD DEPLOYMENT (Fly.io)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*Cloud.*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {gsub(/^Cloud - /, "", $$2); printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "🏠 LOCAL DEPLOYMENT (Docker Compose)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*Local.*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {gsub(/^Local - /, "", $$2); printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "🔧 GENERAL COMMANDS"
	@grep -E '^[a-zA-Z_-]+:.*?## .*General.*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {gsub(/^General - /, "", $$2); printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""

#################################################################################
# SETUP COMMANDS
#################################################################################

setup: ## Setup cloud deployment environment (core dependencies only)
	@echo "Setting up cloud deployment environment..."
	@bash -c "source ./scripts/utils.sh && check_production_deps"
	@./scripts/generate-config.sh
	@echo "✓ Next: make deploy"

setup-local: ## Setup local deployment environment (includes docker-compose)
	@echo "Setting up local deployment environment..."
	@bash -c "source ./scripts/utils.sh && check_local_deps"
	@./scripts/generate-config.sh
	@echo "✓ Next: make start"

#################################################################################
# LOCAL DEPLOYMENT COMMANDS (Docker Compose)
#################################################################################

start: ## Local - Launch local deployment environment
	./scripts/setup-local.sh start

stop: ## Local - Stop local deployment environment  
	./scripts/setup-local.sh stop

logs-local: ## Local - Show local deployment logs
	./scripts/setup-local.sh logs

restart: stop start ## Local - Restart local deployment environment

clean: ## Local - Clean up local environment (removes all data)
	./scripts/setup-local.sh cleanup

shell: ## Local - Open shell in local deployment container
	docker-compose exec n8n sh

build: ## Local - Build Docker image locally
	docker-compose build

pull: ## Local - Pull latest n8n image
	docker-compose pull

backup-local: ## Local - Create backup from local deployment
	./scripts/backup.sh backup-local

restore-local: ## Local - Restore backup to local deployment (usage: make restore-local BACKUP=filename)
	@if [ -z "$(BACKUP)" ]; then \
		echo "Error: Please specify backup file with BACKUP=filename"; \
		echo "Usage: make restore-local BACKUP=backups/n8n_local_backup_20231201_120000.tar.gz"; \
		exit 1; \
	fi
	@echo "🚨 RESTORE WARNING - This will overwrite local deployment data!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ]
	./scripts/backup.sh restore-local $(BACKUP)

local-upgrade: backup-local pull build stop start ## Local - Full day-2 upgrade with backup

reset: clean setup-local ## Local - Complete reset of local environment

#################################################################################
# CLOUD DEPLOYMENT COMMANDS (Fly.io)
#################################################################################

deploy: ## Cloud - Deploy to Fly.io
	@echo "Deploying to Fly.io..."
	./scripts/deploy.sh

backup-cloud: ## Cloud - Create backup from cloud deployment
	./scripts/backup.sh backup-cloud

restore-cloud: ## Cloud - Restore backup to cloud deployment (usage: make restore-cloud BACKUP=filename)
	@if [ -z "$(BACKUP)" ]; then \
		echo "Error: Please specify backup file with BACKUP=filename"; \
		echo "Usage: make restore-cloud BACKUP=backups/n8n_cloud_backup_20231201_120000.tar.gz"; \
		exit 1; \
	fi
	@echo "🚨 RESTORE WARNING - This will overwrite cloud deployment data!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ]
	./scripts/backup.sh restore-cloud $(BACKUP)

status: ## Cloud - Check cloud deployment status
	@APP_NAME=$$(yq eval '.app.name' config.yaml) && \
	fly status -a $$APP_NAME

ssh: ## Cloud - SSH into cloud deployment container
	@APP_NAME=$$(yq eval '.app.name' config.yaml) && \
	fly ssh console -a $$APP_NAME

logs-cloud: ## Cloud - Show cloud deployment logs
	@APP_NAME=$$(yq eval '.app.name' config.yaml) && \
	fly logs -n -a $$APP_NAME

logs-cloud-follow: ## Cloud - Follow cloud deployment logs in real-time
	@APP_NAME=$$(yq eval '.app.name' config.yaml) && \
	fly logs -a $$APP_NAME -f

resume: ## Cloud - Resume cloud machine (start from stopped)
	@APP_NAME=$$(yq eval '.app.name' config.yaml) && \
	fly machine start -a $$APP_NAME

suspend: ## Cloud - Stop cloud machine (saves compute costs)
	@APP_NAME=$$(yq eval '.app.name' config.yaml) && \
	fly machine stop -a $$APP_NAME

machine-list: ## Cloud - List cloud machines
	@APP_NAME=$$(yq eval '.app.name' config.yaml) && \
	fly machine list -a $$APP_NAME

secrets-list: ## Cloud - List cloud secrets
	@APP_NAME=$$(yq eval '.app.name' config.yaml) && \
	fly secrets list -a $$APP_NAME

env-list: ## Cloud - List cloud environment variables
	@APP_NAME=$$(yq eval '.app.name' config.yaml) && \
	fly config env -a $$APP_NAME

production-deploy: check-deps backup-cloud deploy status ## Cloud - Full day-2 deployment with backup

auth: ## Cloud - Authenticate with Fly.io
	fly auth login

whoami: ## Cloud - Show current Fly.io user
	fly auth whoami


#################################################################################
# GENERAL COMMANDS
#################################################################################

list-backups: ## General - List available backup files
	./scripts/backup.sh list

cleanup-backups: ## General - Remove old backups (keep last 5 of each type)
	./scripts/backup.sh cleanup

check-deps: ## General - Check if required dependencies are installed
	@bash -c "source ./scripts/utils.sh && check_production_deps && echo '✓ All cloud dependencies found'"
	@bash -c "source ./scripts/utils.sh && check_local_deps && echo '✓ All local dependencies found'"

config: ## General - Show current configuration status
	@echo "Current Configuration:"
	@echo "====================="
	@echo "Local deployment:"
	@docker-compose ps 2>/dev/null || echo "  No local deployment running"
	@echo ""
	@echo "Cloud deployment status:"
	@APP_NAME=$$(yq eval '.app.name' config.yaml) && \
	fly status -a $$APP_NAME
	@echo ""
	@if [ -f config.yaml ]; then \
		echo "Config file: ✓ config.yaml exists"; \
	else \
		echo "Config file: ❌ config.yaml missing (run 'make setup' or 'make setup-local')"; \
	fi