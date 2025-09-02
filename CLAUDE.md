# CLAUDE.md - Maintenance Guide for n8n Deployment

This guide provides comprehensive information for future maintenance and development of the n8n deployment on Fly.io.

## Architecture Overview

### Deployment Stack
- **Platform**: Fly.io (region configurable via `config.yaml`)
- **Container**: Custom Docker image based on `n8nio/n8n:latest`
- **Database**: SQLite (suitable for single-instance deployments)
- **Storage**: Fly.io persistent volume (3GB, mounted at `/home/node/.n8n`)
- **Security**: n8n user management, HTTPS enforced, non-root container user

### Key Design Decisions

1. **SQLite over PostgreSQL**: Chosen for simplicity and adequate performance for single-user/small team use
2. **n8n User Management**: Built-in user system provides better workflow management than basic auth
3. **YAML Configuration**: Clean config.yaml with comments, auto-generated encryption keys and webhook URLs
4. **Minimal Resources**: 1 CPU/1GB RAM - cost-effective starting point
5. **Hash-based Secret Management**: Intelligent secret change detection to minimize deployment restarts

## Updating n8n Version

### Automated Update Process
```bash
# 1. Check current version
fly ssh console -a $(yq eval '.app.name' config.yaml) -C "n8n --version"

# 2. Create backup before update
./backup.sh backup

# 3. Update Dockerfile base image
# Edit Dockerfile: FROM n8nio/n8n:latest -> FROM n8nio/n8n:X.Y.Z

# 4. Deploy update
./deploy.sh

# 5. Verify update
fly ssh console -a $(yq eval '.app.name' config.yaml) -C "n8n --version"
```

### Manual Version Pinning
For stability, consider pinning to specific versions:
```dockerfile
FROM n8nio/n8n:1.15.2  # Instead of :latest
```

## Resource Configuration

### Adjusting Resources
Edit `fly.toml` to modify CPU and memory:
```toml
[[vm]]
  cpu_kind = "shared"      # or "performance"
  cpus = 2                 # Increase CPU
  memory_mb = 2048         # Increase RAM
```



## Backup and Restore Procedures

### Automated Backup Strategy
```bash
# Set up daily backups (cron job example)
0 2 * * * /path/to/backup.sh backup && /path/to/backup.sh cleanup
```

### Backup Contents
The backup includes:
- SQLite database (`database.sqlite`)
- n8n configuration files
- Workflow data
- Credentials (encrypted)
- Settings and preferences

### Disaster Recovery
```bash
# 1. Restore from backup
./backup.sh restore backups/n8n_backup_YYYYMMDD_HHMMSS.tar.gz

# 2. Verify data integrity
fly ssh console -a $(yq eval '.app.name' config.yaml) -C "ls -la /home/node/.n8n/"

# 3. Test application functionality
curl -I https://$(yq eval '.app.name' config.yaml).fly.dev
```

## Secret Management Strategy

### Hash-Based Change Detection

Our deployment uses an intelligent secret management system to minimize machine restarts:

**The Problem:** Every `fly secrets set` command triggers a machine restart. Traditional approaches would cause multiple restarts during deployment.

**Our Solution:**
1. **Calculate hash** of sensitive values (encryption key + SMTP password) from config.yaml
2. **Store hash** as `SECRETS_HASH` environment variable (visible via `fly config env`)
3. **Compare hashes** on each deployment to detect actual value changes
4. **Batch update** secrets only when hash differs, in single command

**Benefits:**
- **Minimal restarts**: Only 1 restart for config changes, 2 for secret changes
- **Automatic detection**: No manual tracking of what changed
- **Single command**: All secrets updated together, not individually
- **No local state**: Hash stored in Fly.io, travels with deployment

**Usage:**
```bash
# Change secrets in config.yaml
vim config.yaml

# Deploy automatically detects changes
make deploy  # Will update secrets if hash differs
```

### Manual Secret Management

If you need to bypass the automatic system:
```bash
# View current secrets (names only)
make secrets-list

# View environment variables (including SECRETS_HASH)
make env-list

# Manually update specific secret
fly secrets set N8N_SMTP_PASS=new-password -a $(yq eval '.app.name' config.yaml)
```

## Common Maintenance Tasks

### Viewing Logs
```bash
# Real-time logs
make logs-prod-follow

# Historical logs
fly logs -a $(yq eval '.app.name' config.yaml) --since=24h
```

### Accessing the Container
```bash
# SSH into running container
make ssh

# Execute commands
fly ssh console -a $(yq eval '.app.name' config.yaml) -C "df -h"
```

### Managing Secrets
```bash
# List current secrets
make secrets-list

# Update secrets
fly secrets set N8N_SMTP_PASS=new-password -a $(yq eval '.app.name' config.yaml)

# Remove secrets
fly secrets unset OLD_SECRET -a $(yq eval '.app.name' config.yaml)
```

### Volume Management
```bash
# List volumes
fly volumes list -a $(yq eval '.app.name' config.yaml)

# Extend volume size
fly volumes extend <volume-id> --size 10 -a $(yq eval '.app.name' config.yaml)

# Create additional volume (for scaling)
fly volumes create n8n_data_2 --region fra --size 5 -a $(yq eval '.app.name' config.yaml)
```

## Security Best Practices

### Regular Security Updates
1. **Monthly**: Update base n8n image
2. **Weekly**: Review Fly.io security bulletins
3. **As needed**: Rotate authentication credentials

### Authentication Hardening
```bash
# Enable stronger authentication (if/when n8n supports it)
fly secrets set N8N_USER_MANAGEMENT_DISABLED=false -a $(yq eval '.app.name' config.yaml)
```

### Network Security
- HTTPS is enforced by default
- Consider VPN access for sensitive workflows
- Review webhook URLs for exposed endpoints

## Monitoring and Alerting

### Built-in Monitoring
- Fly.io dashboard: https://fly.io/dashboard
- Health checks configured in `fly.toml`
- Application metrics via `/metrics` endpoint

### Custom Monitoring Setup
```bash
# Enable metrics collection
fly env set N8N_METRICS=true -a $(yq eval '.app.name' config.yaml)

# Configure external monitoring (Prometheus/Grafana)
# Add monitoring configuration to fly.toml if needed
```

### Alerting
Set up Fly.io alerts for:
- Application downtime
- High resource usage
- Failed deployments

## Performance Optimization

### Database Optimization
```sql
-- Connect to SQLite and run maintenance
VACUUM;
REINDEX;
ANALYZE;
```

### Resource Monitoring
```bash
# Check resource usage
fly ssh console -a $(yq eval '.app.name' config.yaml) -C "top"
fly ssh console -a $(yq eval '.app.name' config.yaml) -C "df -h"
```

### Workflow Optimization
- Review long-running workflows
- Optimize webhook response times
- Consider workflow scheduling

## Troubleshooting Guide

### Application Won't Start
1. Check logs: `make logs-prod`
2. Verify secrets: `make secrets-list`
3. Check volume mount: `fly ssh console -a $(yq eval '.app.name' config.yaml) -C "ls -la /home/node/.n8n/"`

### Performance Issues
1. Monitor resources: `make machine-list`
2. Check database size: `fly ssh console -a $(yq eval '.app.name' config.yaml) -C "du -sh /home/node/.n8n/"`
3. Review workflow complexity

### Backup/Restore Issues
1. Verify SSH access: `make ssh`
2. Check disk space: `fly ssh console -a $(yq eval '.app.name' config.yaml) -C "df -h"`
3. Validate backup file integrity

## Development Workflow

### Local Development Setup
```bash
# Start local environment
./setup-local.sh start

# Make changes to configuration
# Test locally

# Deploy to production
./deploy.sh
```

### Configuration Changes
1. Update relevant files (Dockerfile, fly.toml, docker-compose.yml)
2. Test locally first
3. Create backup before deploying
4. Deploy and verify

### Adding New Features
1. Research n8n configuration options
2. Test in local environment
3. Update documentation
4. Deploy with monitoring

## Useful Commands Reference

```bash
# Deployment
make deploy                              # Full deployment via Makefile
./deploy.sh                              # Direct script execution

# Management
make status                              # Check status
make machine-list                        # List machines
fly machine restart -a $(yq eval '.app.name' config.yaml)      # Restart application

# Backup/Restore
make backup                             # Create backup
make list-backups                       # List backups  
make cleanup-backups                    # Clean old backups

# Local Development
make dev                                # Start local environment
make logs                               # View local logs
make clean                              # Reset local env
```

## Future Enhancements

### Potential Improvements
1. **Multi-user support**: Configure LDAP/SSO integration
2. **PostgreSQL migration**: External database for scaling beyond single instance
3. **CI/CD pipeline**: Automate deployments with GitHub Actions
4. **Automatic backups**: Schedule daily/weekly backups via cron

### Cost Optimization
- Monitor usage patterns
- Right-size resources based on actual usage
- Consider Fly.io's auto-suspend for development instances

## Support Resources

- **n8n Documentation**: https://docs.n8n.io/
- **Fly.io Docs**: https://fly.io/docs/
- **n8n Community**: https://community.n8n.io/
- **Fly.io Community**: https://community.fly.io/