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
	@echo "  Copy .env.example to .env and configure before first use"

# Local Development
setup: ## Setup local development environment
	@echo "Setting up local development environment..."
	@cp -n .env.example .env || true
	@echo "✓ Created .env file (edit with your values)"
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
	fly status -a matanlb-n8n

ssh: ## SSH into production container
	fly ssh console -a matanlb-n8n

logs-prod: ## Show production logs
	fly logs -a matanlb-n8n

logs-prod-follow: ## Follow production logs in real-time
	fly logs -a matanlb-n8n -f

# Utility Commands
check-deps: ## Check if required dependencies are installed
	@echo "Checking dependencies..."
	@command -v docker >/dev/null 2>&1 || { echo "❌ Docker not found"; exit 1; }
	@command -v docker-compose >/dev/null 2>&1 || { echo "❌ Docker Compose not found"; exit 1; }
	@command -v fly >/dev/null 2>&1 || { echo "❌ Fly CLI not found"; exit 1; }
	@echo "✓ All dependencies found"

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
	@if [ ! -f .env ]; then echo "❌ .env file not found"; exit 1; fi
	@APP_NAME=$$(grep "^APP_NAME=" .env | cut -d= -f2) && \
	fly machine start -a $$APP_NAME

stop-prod: ## Stop production machine (saves compute costs)
	@if [ ! -f .env ]; then echo "❌ .env file not found"; exit 1; fi
	@APP_NAME=$$(grep "^APP_NAME=" .env | cut -d= -f2) && \
	fly machine stop -a $$APP_NAME

# Production Scaling
scale-up: ## Scale production to 2 instances
	@APP_NAME=$$(grep "^APP_NAME=" .env | cut -d= -f2) && \
	fly scale count 2 -a $$APP_NAME

scale-down: ## Scale production to 1 instance
	@APP_NAME=$$(grep "^APP_NAME=" .env | cut -d= -f2) && \
	fly scale count 1 -a $$APP_NAME

# Monitoring
ps: ## Show running processes in production
	fly ssh console -a matanlb-n8n -C "ps aux"

disk: ## Show disk usage in production
	fly ssh console -a matanlb-n8n -C "df -h"

volume-list: ## List production volumes
	fly volumes list -a matanlb-n8n

machine-list: ## List production machines
	fly machine list -a matanlb-n8n

# Security
secrets-list: ## List production secrets
	fly secrets list -a matanlb-n8n

env-list: ## List production environment variables
	fly env list -a matanlb-n8n

# Quick Development Workflow
quick-start: setup dev ## Quick setup and start for new users

# Production Workflow
production-deploy: check-deps backup deploy status ## Full production deployment with backup

# Emergency
emergency-restore: ## Emergency restore (usage: make emergency-restore BACKUP=filename)
	@echo "🚨 EMERGENCY RESTORE - This will overwrite production data!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ]
	@$(MAKE) restore BACKUP=$(BACKUP)

# Maintenance
update: ## Update to latest n8n version (manual Dockerfile edit required)
	@echo "To update n8n:"
	@echo "1. Edit Dockerfile to pin to specific version"
	@echo "2. Run: make production-deploy"
	@echo "3. Verify: make status"

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
	@fly status -a matanlb-n8n 2>/dev/null || echo "  Not deployed or not authenticated"
	@echo ""
	@if [ -f .env ]; then \
		echo "Environment file: ✓ .env exists"; \
	else \
		echo "Environment file: ❌ .env missing (run 'make setup')"; \
	fi