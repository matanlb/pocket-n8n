# n8n Self-Hosted Deployment on Fly.io

A complete homelab-style setup for deploying n8n workflow automation platform on Fly.io with proper security, persistence, and backup capabilities.

## Prerequisites

- [Fly.io CLI](https://fly.io/docs/getting-started/installing-flyctl/) installed and configured
- [Docker](https://docs.docker.com/get-docker/) installed (for local development)
- [Docker Compose](https://docs.docker.com/compose/install/) installed

## Quick Start

### 1. Setup Environment Variables

```bash
# Copy the example environment file
cp .env.example .env

# Edit .env with your values
nano .env
```

**Required variables:**
- `N8N_BASIC_AUTH_USER` - Username for n8n login
- `N8N_BASIC_AUTH_PASSWORD` - Password for n8n login  
- `N8N_ENCRYPTION_KEY` - Encryption key for n8n data (generate with: `openssl rand -base64 32`)

### 2. Local Development

```bash
# Make scripts executable
chmod +x setup-local.sh deploy.sh backup.sh

# Start local development environment
./setup-local.sh start

# Access n8n at http://localhost:5678
```

### 3. Deploy to Fly.io

```bash
# Login to Fly.io
fly auth login

# Deploy to production
./deploy.sh
```

Your n8n instance will be available at: https://matanlb-n8n.fly.dev

## Environment Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `N8N_BASIC_AUTH_USER` | Admin username | `admin` |
| `N8N_BASIC_AUTH_PASSWORD` | Admin password | `your-secure-password` |
| `N8N_ENCRYPTION_KEY` | Data encryption key | `generated-with-openssl` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `WEBHOOK_URL` | Base URL for webhooks | `https://matanlb-n8n.fly.dev` |
| `N8N_LOG_LEVEL` | Logging level | `info` |
| `GENERIC_TIMEZONE` | Timezone | `UTC` |

## Scripts

### Local Development

```bash
./setup-local.sh start    # Start local environment
./setup-local.sh stop     # Stop local environment  
./setup-local.sh logs     # View logs
./setup-local.sh cleanup  # Remove all containers and volumes
```

### Deployment

```bash
./deploy.sh               # Deploy to Fly.io
```

### Backup & Restore

```bash
./backup.sh backup        # Create backup (zero downtime)
./backup.sh restore <file> # Restore from backup (brief downtime)
./backup.sh list          # List available backups
./backup.sh cleanup       # Remove old backups (keep last 5)
```

## Architecture

- **Database**: SQLite (persisted in Fly.io volume)
- **Storage**: 3GB persistent volume mounted at `/home/n8nuser/.n8n`
- **Resources**: 1 CPU, 1GB RAM (configurable in `fly.toml`)
- **Region**: Frankfurt (`fra`) for lowest latency to Israel
- **Security**: Basic authentication, HTTPS enforced, non-root user

## File Structure

```
.
├── Dockerfile              # n8n container configuration
├── fly.toml                # Fly.io deployment configuration  
├── docker-compose.yml      # Local development setup
├── .env.example            # Environment variables template
├── scripts/
│   └── utils.sh           # Shared utilities for scripts
├── deploy.sh              # Deployment script
├── setup-local.sh         # Local development script
├── backup.sh              # Backup/restore script
└── backups/               # Backup files directory
```

## Security Best Practices

1. **Strong Passwords**: Use strong, unique passwords for `N8N_BASIC_AUTH_PASSWORD`
2. **Encryption Key**: Generate a secure encryption key with `openssl rand -base64 32`
3. **HTTPS Only**: All traffic is forced to HTTPS in production
4. **Non-root User**: Container runs as non-root user for security
5. **Environment Variables**: Secrets are stored as Fly.io secrets, not in code

## Troubleshooting

### Common Issues

**n8n not responding after deployment:**
```bash
# Check application status
fly status -a matanlb-n8n

# View logs
fly logs -a matanlb-n8n

# Check machine status
fly machine list -a matanlb-n8n
```

**Local development issues:**
```bash
# Check container status
docker-compose ps

# View logs
docker-compose logs n8n

# Restart services
docker-compose restart
```

**Backup/restore failures:**
- Ensure you're authenticated with Fly.io: `fly auth whoami`
- Check if the app is running: `fly status -a matanlb-n8n`
- Verify backup file exists and is not corrupted

### Performance Tuning

**Increase resources** (edit `fly.toml`):
```toml
[[vm]]
  cpu_kind = "shared"
  cpus = 2
  memory_mb = 2048
```

**Scale to multiple regions:**
```bash
fly scale count 2 -a matanlb-n8n
fly regions add lhr -a matanlb-n8n  # Add London region
```

## Support

- [n8n Documentation](https://docs.n8n.io/)
- [Fly.io Documentation](https://fly.io/docs/)
- [Project Issues](https://github.com/yourusername/n8n-fly-deployment/issues)

## License

This deployment configuration is provided as-is. n8n itself is licensed under the [Sustainable Use License](https://github.com/n8n-io/n8n/blob/master/LICENSE.md).