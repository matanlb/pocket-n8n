# Claude Code Prompt: Deploy n8n on Fly.io

I want to deploy a self-hosted n8n workflow automation platform on Fly.io. This is an empty repository, so I need you to generate all the necessary files for deployment but **stop before actually launching/deploying**.

## Required Files to Generate:

### Core Deployment Files
- `Dockerfile` - Optimized for n8n with proper security and performance settings
- `fly.toml` - Fly.io configuration file with appropriate resource allocation
- `docker-compose.yml` - For local development and testing

### Scripts
- `deploy.sh` - Deployment script that handles Fly.io deployment steps
- `setup-local.sh` - Script to set up local development environment
- `backup.sh` - Script for backing up n8n data/workflows

### Documentation
- `README.md` - Comprehensive setup guide including:
  - Prerequisites and dependencies
  - Local development setup instructions
  - Environment variables needed (with examples but no real values)
  - Deployment process overview
  - Troubleshooting common issues
- `CLAUDE.md` - Future maintenance guide including:
  - Architecture overview
  - How to update n8n version
  - Scaling considerations
  - Backup and restore procedures
  - Common maintenance tasks
  - Security best practices

### Configuration
- `.env.example` - Template for environment variables
- `.dockerignore` - Optimize Docker build context
- `.gitignore` - Appropriate for Node.js/n8n project
- `healthcheck.js` - Custom health check script for Fly.io

## Specific Requirements:

1. **Security**: Include proper security headers, user management setup, and SSL/TLS configuration
2. **Performance**: Configure appropriate resource limits and caching
3. **Persistence**: Set up proper volume mounting for n8n data persistence
4. **Environment Variables**: Document all required env vars including:
   - Database connection (if using external DB)
   - n8n configuration (webhook URL, encryption key, etc.)
   - Fly.io specific variables
   - Any API keys or secrets needed

5. **Local Development**: Ensure the setup works locally before deployment
6. **Monitoring**: Include basic health checks and logging configuration

## What NOT to do:
- Don't actually deploy or run `fly deploy`
- Don't include real secrets or API keys
- Don't make any external API calls

## Additional Considerations:
Please suggest any other files or configurations that would be beneficial for a production-ready n8n deployment on Fly.io that I might have missed.

Generate all files with proper comments explaining configuration choices and next steps.
