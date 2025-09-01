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
- `N8N_ENCRYPTION_KEY` - Encryption key for n8n data (generate with: `openssl rand -base64 32`)

**Optional but recommended variables:**
- SMTP settings for email functionality (enables Send Email nodes, user invitations, password resets)
- `GENERIC_TIMEZONE` - Set to your local timezone (e.g., `Europe/London` or `America/New_York`)

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

Your n8n instance will be available at: https://your-app-name.fly.dev

## Environment Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `N8N_ENCRYPTION_KEY` | Data encryption key | `generated-with-openssl` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `APP_NAME` | Fly.io app name | `pocket-n8n` |
| `WEBHOOK_URL` | Base URL for webhooks | `https://pocket-n8n.fly.dev` |
| `FLY_REGION` | Deployment region (3-letter code) | `fra` (Frankfurt) |
| `N8N_LOG_LEVEL` | Logging level | `info` |
| `GENERIC_TIMEZONE` | Timezone | `UTC` |

**Choosing a Region:** Select the region closest to your users for best performance. See [Fly.io Regions](https://fly.io/docs/reference/regions/) for all available options. Examples:
- `fra` - Frankfurt, Germany
- `iad` - Ashburn, USA (East Coast)
- `nrt` - Tokyo, Japan

### Email Configuration (Optional but Recommended)

**Why SMTP is important:** Without SMTP configuration, you lose critical n8n functionality:
- Send Email workflow nodes won't work
- "Send and Wait for Response" interactive workflows are disabled
- Cannot invite additional users via email
- No password reset emails for user management

| Variable | Description | Example |
|----------|-------------|---------|
| `N8N_EMAIL_MODE` | Email mode | `smtp` |
| `N8N_SMTP_HOST` | SMTP server | `smtp.gmail.com` |
| `N8N_SMTP_PORT` | SMTP port | `587` |
| `N8N_SMTP_USER` | SMTP username | `your-email@gmail.com` |
| `N8N_SMTP_PASS` | SMTP password/app password | `your-gmail-app-password` |
| `N8N_SMTP_SENDER` | From email address | `your-email@gmail.com` |

## Scripts

### Local Development

```bash
make dev                  # Start local environment
make stop                 # Stop local environment  
make logs                 # View logs
make clean                # Remove all containers and volumes
```

### Deployment

```bash
make deploy               # Smart deployment with secret change detection
```

**Smart Deployment Strategy:**

Our deployment script uses hash-based secret change detection to minimize machine restarts:

**Why this matters:** Every `fly secrets set` command triggers a machine restart. Without optimization, changing multiple secrets would cause multiple restarts plus the deployment restart.

**How we solve it:**
1. **Hash comparison**: Calculate SHA256 hash of sensitive values (`N8N_ENCRYPTION_KEY` + `N8N_SMTP_PASS`)
2. **Store hash as env var**: Non-sensitive hash stored as `SECRETS_HASH` environment variable
3. **Smart detection**: Only update secrets when hash differs from stored value
4. **Batch updates**: All secret changes happen in single command

**Result:**
- **Secrets unchanged**: 1 restart (deploy only)
- **Secrets changed**: 2 restarts (secrets batch update + deploy)
- **Maximum efficiency**: Never more than 2 restarts, regardless of configuration changes

### Backup & Restore

```bash
make backup               # Create backup (zero downtime)
make list-backups         # List available backups
make cleanup-backups      # Remove old backups (keep last 5)
```

## Architecture

- **Database**: SQLite (persisted in Fly.io volume)
- **Storage**: 3GB persistent volume mounted at `/home/node/.n8n`
- **Resources**: 1 CPU, 1GB RAM (configurable in `fly.toml`)
- **Region**: Configurable via `FLY_REGION` (defaults to Frankfurt)
- **Security**: n8n user management, HTTPS enforced, non-root container user

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

1. **Strong n8n Passwords**: Use strong passwords for your n8n user accounts
2. **Encryption Key**: Generate a secure encryption key with `openssl rand -base64 32`
3. **HTTPS Only**: All traffic is forced to HTTPS in production
4. **Non-root User**: Container runs as existing `node` user for security
5. **Secret Management**: Sensitive data stored as Fly.io secrets with intelligent change detection
6. **Configurable Deployment**: App name and region configurable via .env file

## Troubleshooting

### Common Issues

**n8n not responding after deployment:**
```bash
# Check application status
make status

# View logs
make logs-prod

# Check machine status
make machine-list
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
- Check if the app is running: `make status`
- Verify backup file exists and is not corrupted

### Performance Tuning

**Increase resources** (edit `fly.toml`):
```toml
[[vm]]
  cpu_kind = "shared"
  cpus = 2
  memory_mb = 2048
```


## Support

- [n8n Documentation](https://docs.n8n.io/)
- [Fly.io Documentation](https://fly.io/docs/)
- [Project Issues](https://github.com/yourusername/n8n-fly-deployment/issues)

## License

This deployment configuration is provided as-is. n8n itself is licensed under the [Sustainable Use License](https://github.com/n8n-io/n8n/blob/master/LICENSE.md).