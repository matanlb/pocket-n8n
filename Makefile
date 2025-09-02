# n8n Fly.io Deployment Makefile
# Provides convenient shortcuts for common operations

.PHONY: help setup dev start stop logs restart clean deploy backup restore list-backups cleanup-backups status ssh

# Default target
help: ## Show this help message
	@echo "n8n Fly.io Deployment - Available Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Environment:"
	@echo "  Run 'make setup' or 'make setup-local' to generate config.yaml"

# Local Development
setup: ## Setup production environment (core dependencies only)
	@echo "Setting up production environment..."
	@bash -c "source ./scripts/utils.sh && check_production_deps"
	@./scripts/generate-config.sh
	@echo "✓ Next: make deploy"

setup-local: ## Setup local development environment (includes docker-compose)
	@echo "Setting up local development environment..."
	@bash -c "source ./scripts/utils.sh && check_local_deps"
	@./scripts/generate-config.sh
	@echo "✓ Next: make dev"

dev: ## Start local development environment
	./setup-local.sh start

start: dev ## Alias for dev

stop: ## Stop local development environment
	./setup-local.sh stop

logs: ## Show local development logs
	./setup-local.sh logs

restart: stop dev ## Restart local development environment

clean: ## Clean up local environment (removes all data)
	./setup-local.sh cleanup

# Production Deployment
deploy: ## Deploy to Fly.io production
	@echo "Deploying to Fly.io..."
	./deploy.sh

# Backup Operations
backup: ## Create backup from production
	./backup.sh backup

restore: ## Restore backup to production (usage: make restore BACKUP=filename)
	@if [ -z "$(BACKUP)" ]; then \
		echo "Error: Please specify backup file with BACKUP=filename"; \
		echo "Usage: make restore BACKUP=backups/n8n_backup_20231201_120000.tar.gz"; \
		exit 1; \
	fi
	./backup.sh restore $(BACKUP)

list-backups: ## List available backup files
	./backup.sh list

cleanup-backups: ## Remove old backups (keep last 5)
	./backup.sh cleanup

# Production Management
status: ## Check production application status
	@APP_NAME=$$(yq eval '.app.name' config.yaml) && \
	fly status -a $$APP_NAME

ssh: ## SSH into production container
	@APP_NAME=$$(yq eval '.app.name' config.yaml) && \
	fly ssh console -a $$APP_NAME

logs-prod: ## Show production logs
	@APP_NAME=$$(yq eval '.app.name' config.yaml) && \
	fly logs -a $$APP_NAME

logs-prod-follow: ## Follow production logs in real-time
	@APP_NAME=$$(yq eval '.app.name' config.yaml) && \
	fly logs -a $$APP_NAME -f

# Utility Commands
check-deps: ## Check if required dependencies are installed
	@bash -c "source ./scripts/utils.sh && check_production_deps && echo '✓ All dependencies found'"

auth: ## Authenticate with Fly.io
	fly auth login

whoami: ## Show current Fly.io user
	fly auth whoami

# Development Helpers
shell: ## Open shell in local development container
	docker-compose exec n8n sh

build: ## Build Docker image locally
	docker-compose build

pull: ## Pull latest n8n image
	docker-compose pull

# Production Machine Control
resume-prod: ## Resume production machine (start from stopped)
	@APP_NAME=$$(yq eval '.app.name' config.yaml) && \
	fly machine start -a $$APP_NAME

stop-prod: ## Stop production machine (saves compute costs)
	@APP_NAME=$$(yq eval '.app.name' config.yaml) && \
	fly machine stop -a $$APP_NAME


# Monitoring
machine-list: ## List production machines
	@APP_NAME=$$(yq eval '.app.name' config.yaml) && \
	fly machine list -a $$APP_NAME

# Security
secrets-list: ## List production secrets
	@APP_NAME=$$(yq eval '.app.name' config.yaml) && \
	fly secrets list -a $$APP_NAME

env-list: ## List production environment variables
	@APP_NAME=$$(yq eval '.app.name' config.yaml) && \
	fly config env -a $$APP_NAME

# Quick Development Workflow
quick-start: setup dev ## Quick setup and start for new users

# Production Workflow
production-deploy: check-deps backup deploy status ## Full production deployment with backup

# Emergency
emergency-restore: ## Emergency restore (usage: make emergency-restore BACKUP=filename)
	@echo "🚨 EMERGENCY RESTORE - This will overwrite production data!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ]
	@$(MAKE) restore BACKUP=$(BACKUP)

# Development Reset
reset: clean setup ## Complete reset of local environment

# Show current configuration
config: ## Show current configuration
	@echo "Current Configuration:"
	@echo "====================="
	@echo "Local containers:"
	@docker-compose ps 2>/dev/null || echo "  No local containers running"
	@echo ""
	@echo "Production status:"
	@APP_NAME=$$(yq eval '.app.name' config.yaml) && \
	fly status -a $$APP_NAME
	@echo ""
	@if [ -f config.yaml ]; then \
		echo "Config file: ✓ config.yaml exists"; \
	else \
		echo "Config file: ❌ config.yaml missing (run 'make setup')"; \
	fi
