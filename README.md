# pocket-n8n
Ready to go deploy setup for n8n, with a bill that can fit your pocket.

Easily deploy and maintain n8n workflow automation to Fly.io cloud or to your home-lab.

## Table of Contents

- [Capabilities](#capabilities)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Scripts](#scripts)
- [Architecture](#architecture)
- [Security Best Practices](#security-best-practices)
- [Troubleshooting](#troubleshooting)
- [Support](#support)

## Capabilities

🚀 **Dual deployment options** - Choose between Fly.io cloud deployment or local Docker Compose setup

💰 **Affordable cloud hosting** - Fly.io deployment runs for just over $6/month (1 CPU, 1GB RAM, 3GB storage)

🏠 **Local deployment support** - Full Docker Compose setup for home-lab or self-hosted environments

🔐 **Basic security** - HTTPS enforcement, n8n user management, and encrypted data storage

💾 **Backup and restore** - Create backups from both cloud and local deployments with simple commands

⚙️ **Simple configuration** - Auto-generated secure configs with encryption keys and webhook URLs

🛠️ **Operational commands** - Makefile with organized commands for deployment, backup, and maintenance tasks

📧 **Email integration** - Optionally configure n8n SMTP for workflow notifications and user invitations

## Prerequisites

### For Deployment to Fly.io
- [Fly.io CLI](https://fly.io/docs/getting-started/installing-flyctl/) installed and configured
- [yq](https://github.com/mikefarah/yq#install) installed

### For Local Deployment
- [Docker](https://docs.docker.com/get-docker/) installed (for local deployment)
- [Docker Compose](https://docs.docker.com/compose/install/) installed
- [yq](https://github.com/mikefarah/yq#install) 

## Quick Start

### Setup Configuration

```bash
# For cloud deployment
make setup

# For local deployment
make setup-local
```

Both automatically generates `config.yaml` (which is .gitignore'd) with secure defaults.
The only difference between the two is the prerequisites installation checked.

**Required for cloud deployment (auto-generated):**
- Encryption key for n8n data security
- Username-prefixed webhook URL for global uniqueness

**Optional but recommended:**
- Email/SMTP settings for full n8n functionality (Send Email nodes, user invitations, password resets)
- Timezone configuration to control timing of scheduled workflows

### Deploy to Fly.io

```bash
# Login to Fly.io
fly auth login

# Deploy to cloud
make deploy
```

Your n8n instance will be available at: https://<username>-pocket-n8n.fly.dev

### Local Deployment

```bash
# Start local deployment environment
make dev

# Access n8n at http://localhost:5678
```

## Configuration

Configuration is managed through `config.yaml`, which is auto-generated with secure defaults and excluded from git.

### Core Settings

| Config Key | Target Env Var | Description | Default |
|------------|----------------|-------------|---------|
| `app.name` | - | Fly.io app name | `pocket-n8n` |
| `app.webhook_url` | `WEBHOOK_URL` | Base URL for webhooks | `https://username-pocket-n8n.fly.dev` |
| `app.region` | - | Deployment region | `fra` (Frankfurt) |
| `n8n.encryption_key` | `N8N_ENCRYPTION_KEY` | Data encryption key | Auto-generated |
| `n8n.log_level` | `N8N_LOG_LEVEL` | Logging level | `info` |
| `n8n.timezone` | `GENERIC_TIMEZONE` | Timezone | `UTC` |

**Choosing a Region:** Edit `app.region` in `config.yaml`. For example:
- `fra` - Frankfurt, Germany
- `iad` - Ashburn, USA (East Coast)
- `nrt` - Tokyo, Japan
 
 See [Fly.io Regions](https://fly.io/docs/reference/regions/) for all available options.

### Email Configuration (Optional but Recommended)

**Why SMTP is important:** Without SMTP configuration, you lose critical n8n functionality:
- Send Email workflow nodes won't work
- "Send and Wait for Response" interactive workflows are disabled
- Cannot invite additional users via email
- No password reset emails for user management

| Config Key | Target Env Var | Description | Example |
|------------|----------------|-------------|---------|
| `email.mode` | `N8N_EMAIL_MODE` | Email mode | `smtp` |
| `email.host` | `N8N_SMTP_HOST` | SMTP server | `smtp.gmail.com` |
| `email.port` | `N8N_SMTP_PORT` | SMTP port | `587` |
| `email.user` | `N8N_SMTP_USER` | SMTP username | `your-email@gmail.com` |
| `email.password` | `N8N_SMTP_PASS` | SMTP password/app password | `your-gmail-app-password` |
| `email.sender` | `N8N_SMTP_SENDER` | From email address | `your-email@gmail.com` |

## Scripts

### Local Deployment

```bash
make start                # Start local environment
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
├── docker-compose.yml      # Local deployment setup
├── config.example.yaml     # Configuration template
├── config.yaml             # Generated configuration (auto-created, .gitignore'd)
├── scripts/
│   ├── utils.sh           # Shared utilities for scripts
│   ├── generate-config.sh # Configuration generator
│   ├── deploy.sh          # Deployment script
│   ├── setup-local.sh     # Local deployment script
│   └── backup.sh          # Backup/restore script
└── backups/               # Backup files directory
```

## Security Best Practices

1. **Strong n8n Passwords**: Use strong passwords for your n8n user accounts
2. **Encryption Key**: Generate a secure encryption key with `openssl rand -base64 32`
3. **HTTPS Only**: All traffic is forced to HTTPS in production
4. **Non-root User**: Container runs as existing `node` user for security
5. **Secret Management**: Sensitive data stored as Fly.io secrets with intelligent change detection
6. **Configurable Deployment**: App name and region configurable via config.yaml file

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

**Local deployment issues:**
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
