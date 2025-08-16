# CLAUDE.md - Maintenance Guide for n8n Deployment

This guide provides comprehensive information for future maintenance and development of the n8n deployment on Fly.io.

## Architecture Overview

### Deployment Stack
- **Platform**: Fly.io (Frankfurt region for Israel proximity)
- **Container**: Custom Docker image based on `n8nio/n8n:latest`
- **Database**: SQLite (suitable for single-instance deployments)
- **Storage**: Fly.io persistent volume (3GB, mounted at `/home/n8nuser/.n8n`)
- **Security**: Basic authentication, HTTPS enforced, non-root container user

### Key Design Decisions

1. **SQLite over PostgreSQL**: Chosen for simplicity and adequate performance for single-user/small team use
2. **Basic Auth**: Simple authentication suitable for personal/small team use
3. **Single Region**: Frankfurt region optimized for Israel latency
4. **Minimal Resources**: 1 CPU/1GB RAM - cost-effective starting point

## Updating n8n Version

### Automated Update Process
```bash
# 1. Check current version
fly ssh console -a matanlb-n8n -C "n8n --version"

# 2. Create backup before update
./backup.sh backup

# 3. Update Dockerfile base image
# Edit Dockerfile: FROM n8nio/n8n:latest -> FROM n8nio/n8n:X.Y.Z

# 4. Deploy update
./deploy.sh

# 5. Verify update
fly ssh console -a matanlb-n8n -C "n8n --version"
```

### Manual Version Pinning
For stability, consider pinning to specific versions:
```dockerfile
FROM n8nio/n8n:1.15.2  # Instead of :latest
```

## Scaling Considerations

### Vertical Scaling (More Resources)
Edit `fly.toml`:
```toml
[[vm]]
  cpu_kind = "shared"      # or "performance"
  cpus = 2                 # Increase CPU
  memory_mb = 2048         # Increase RAM
```

### Horizontal Scaling (Multiple Instances)
**Not recommended with SQLite**. For multi-instance:
1. Migrate to PostgreSQL
2. Configure external database
3. Update environment variables
4. Scale instances: `fly scale count 2`

### Database Migration (SQLite → PostgreSQL)
```bash
# 1. Provision PostgreSQL (Fly.io Postgres or external)
fly postgres create n8n-db

# 2. Update environment variables
fly secrets set DB_TYPE=postgresdb -a matanlb-n8n
fly secrets set DB_POSTGRESDB_HOST=<host> -a matanlb-n8n
fly secrets set DB_POSTGRESDB_PASSWORD=<password> -a matanlb-n8n

# 3. Export SQLite data (manual process - n8n doesn't have built-in migration)
# 4. Deploy with new configuration
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
fly ssh console -a matanlb-n8n -C "ls -la /home/n8nuser/.n8n/"

# 3. Test application functionality
curl -I https://matanlb-n8n.fly.dev
```

## Common Maintenance Tasks

### Viewing Logs
```bash
# Real-time logs
fly logs -a matanlb-n8n

# Historical logs
fly logs -a matanlb-n8n --since=24h
```

### Accessing the Container
```bash
# SSH into running container
fly ssh console -a matanlb-n8n

# Execute commands
fly ssh console -a matanlb-n8n -C "df -h"
```

### Managing Secrets
```bash
# List current secrets
fly secrets list -a matanlb-n8n

# Update secrets
fly secrets set N8N_BASIC_AUTH_PASSWORD=new-password -a matanlb-n8n

# Remove secrets
fly secrets unset OLD_SECRET -a matanlb-n8n
```

### Volume Management
```bash
# List volumes
fly volumes list -a matanlb-n8n

# Extend volume size
fly volumes extend <volume-id> --size 10 -a matanlb-n8n

# Create additional volume (for scaling)
fly volumes create n8n_data_2 --region fra --size 5 -a matanlb-n8n
```

## Security Best Practices

### Regular Security Updates
1. **Monthly**: Update base n8n image
2. **Weekly**: Review Fly.io security bulletins
3. **As needed**: Rotate authentication credentials

### Authentication Hardening
```bash
# Enable stronger authentication (if/when n8n supports it)
fly secrets set N8N_USER_MANAGEMENT_DISABLED=false -a matanlb-n8n
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
fly env set N8N_METRICS=true -a matanlb-n8n

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
fly ssh console -a matanlb-n8n -C "top"
fly ssh console -a matanlb-n8n -C "df -h"
```

### Workflow Optimization
- Review long-running workflows
- Optimize webhook response times
- Consider workflow scheduling

## Troubleshooting Guide

### Application Won't Start
1. Check logs: `fly logs -a matanlb-n8n`
2. Verify secrets: `fly secrets list -a matanlb-n8n`
3. Check volume mount: `fly ssh console -a matanlb-n8n -C "ls -la /home/n8nuser/.n8n/"`

### Performance Issues
1. Monitor resources: `fly machine list -a matanlb-n8n`
2. Check database size: `fly ssh console -a matanlb-n8n -C "du -sh /home/n8nuser/.n8n/"`
3. Review workflow complexity

### Backup/Restore Issues
1. Verify SSH access: `fly ssh console -a matanlb-n8n`
2. Check disk space: `fly ssh console -a matanlb-n8n -C "df -h"`
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
./deploy.sh                              # Full deployment
fly deploy -a matanlb-n8n               # Manual deploy

# Management
fly status -a matanlb-n8n               # Check status
fly scale count 1 -a matanlb-n8n        # Scale instances
fly machine restart -a matanlb-n8n      # Restart application

# Backup/Restore
./backup.sh backup                      # Create backup
./backup.sh list                        # List backups
./backup.sh cleanup                     # Clean old backups

# Local Development
./setup-local.sh start                  # Start local
./setup-local.sh logs                   # View logs
./setup-local.sh cleanup                # Reset local env
```

## Future Enhancements

### Potential Improvements
1. **Multi-user support**: Configure LDAP/SSO integration
2. **External database**: Migrate to PostgreSQL for scaling
3. **Redis queue**: Add Redis for workflow queue management
4. **Monitoring stack**: Integrate Prometheus/Grafana
5. **CI/CD pipeline**: Automate deployments
6. **Multi-region**: Deploy across multiple regions

### Cost Optimization
- Monitor usage patterns
- Right-size resources based on actual usage
- Consider Fly.io's auto-suspend for development instances

## Support Resources

- **n8n Documentation**: https://docs.n8n.io/
- **Fly.io Docs**: https://fly.io/docs/
- **n8n Community**: https://community.n8n.io/
- **Fly.io Community**: https://community.fly.io/