# Reliant Stack - Docker Compose Setup

Production-ready Docker Compose stack for n8n, Uptime Kuma, and PostgreSQL on a VPS running Caddy as the host reverse proxy.

## Architecture Overview

- **n8n**: Workflow automation (port `127.0.0.1:5679` → container `5678`)
- **Uptime Kuma**: Monitoring dashboard (port `127.0.0.1:3002` → container `3001`)
- **PostgreSQL**: Database backend (no exposed ports, internal network only)
- **Postgres Backup**: Automated daily backups with retention policy

All services run on an isolated Docker network (`reliant-network`) with proper health checks and dependencies.

## Prerequisites

- Docker Engine installed
- Docker Compose V2 (docker compose, not docker-compose)
- Caddy running on the host (not in Docker)
- Sufficient disk space for PostgreSQL data and backups

## Initial Installation

### 1. Clone or Create the Project Directory

```bash
cd /opt/reliant-stack
```

### 2. Configure Environment Variables

```bash
# Copy the example environment file
cp .env.example .env

# Edit the .env file with secure credentials
nano .env
```

**CRITICAL**: Update these values in `.env`:
- `POSTGRES_PASSWORD`: Strong password for PostgreSQL superuser
- `POSTGRES_NON_ROOT_PASSWORD`: Strong password for n8n database user
- `N8N_DB_PASSWORD`: Must match `POSTGRES_NON_ROOT_PASSWORD`
- `N8N_ENCRYPTION_KEY`: Generate with `openssl rand -hex 32`
- `N8N_JWT_SECRET`: Generate with `openssl rand -hex 32`

### 3. Create Required Directories

```bash
mkdir -p postgres-backups
```

### 4. Start the Stack

```bash
docker compose up -d
```

### 5. Verify All Services Are Running

```bash
docker compose ps
```

All services should show "Up" status.

### 6. Check Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f n8n
docker compose logs -f postgres
docker compose logs -f uptime-kuma
```

## Configure Caddy Reverse Proxy

Add these configurations to your Caddyfile on the **host** (not in Docker):

```caddy
# n8n
temp.reliantcleanandrepair.com {
    reverse_proxy 127.0.0.1:5679
}

# Uptime Kuma (adjust domain as needed)
monitor.reliantcleanandrepair.com {
    reverse_proxy 127.0.0.1:3002
}
```

Then reload Caddy:

```bash
sudo systemctl reload caddy
```

## Service Access

- **n8n**: https://temp.reliantcleanandrepair.com
- **Uptime Kuma**: Configure your own domain in Caddy pointing to `127.0.0.1:3002`

## Updating Services

### Update All Services

```bash
cd /opt/reliant-stack
docker compose pull
docker compose up -d
```

### Update Specific Service

```bash
# Example: Update n8n only
docker compose pull n8n
docker compose up -d n8n
```

### View Update Status

```bash
docker compose ps
docker compose logs -f <service-name>
```

## Backup & Restore

### Automated Backups

The `postgres-backup` container automatically backs up all PostgreSQL databases daily at 2 AM (configurable via `BACKUP_SCHEDULE` in `.env`).

- **Backup Location**: `./postgres-backups/`
- **Retention**: 7 days (configurable via `BACKUP_RETENTION_DAYS`)
- **Format**: Compressed SQL dumps with timestamps

### Manual Backup

```bash
# Create immediate backup
docker compose exec postgres pg_dumpall -U postgres | gzip > postgres-backups/manual-backup-$(date +%Y%m%d-%H%M%S).sql.gz
```

### Restore from Backup

```bash
# Stop services (except postgres)
docker compose stop n8n uptime-kuma postgres-backup

# Restore from backup file
gunzip < postgres-backups/backup-YYYYMMDD-HHMMSS.sql.gz | docker compose exec -T postgres psql -U postgres

# Restart all services
docker compose up -d
```

### Offsite Backup Strategy

**CRITICAL**: Local backups are NOT sufficient for production. Implement one of these:

1. **Rsync to Remote Server** (recommended):
   ```bash
   # Add to crontab: crontab -e
   0 3 * * * rsync -az /opt/reliant-stack/postgres-backups/ user@backup-server:/backups/reliant-stack/
   ```

2. **Cloud Storage (rclone)**:
   ```bash
   # Install rclone and configure cloud provider
   sudo apt install rclone
   rclone config
   
   # Add to crontab
   0 3 * * * rclone sync /opt/reliant-stack/postgres-backups/ remote:reliant-backups/
   ```

3. **S3/Backblaze B2**:
   ```bash
   # Install AWS CLI or B2 CLI
   # Add to crontab with appropriate sync command
   ```

## Maintenance Commands

### View Service Status

```bash
docker compose ps
```

### View Logs

```bash
# All services (follow mode)
docker compose logs -f

# Last 100 lines from specific service
docker compose logs --tail=100 n8n
```

### Restart Services

```bash
# Restart all
docker compose restart

# Restart specific service
docker compose restart n8n
```

### Stop Services

```bash
# Stop all (preserves data)
docker compose stop

# Stop specific service
docker compose stop uptime-kuma
```

### Start Services

```bash
docker compose start
```

### Remove Stack (WARNING: DATA LOSS)

```bash
# Stop and remove containers (keeps volumes)
docker compose down

# Stop, remove containers AND DELETE ALL DATA
docker compose down -v
```

### View Resource Usage

```bash
docker stats
```

## Database Management

### Access PostgreSQL CLI

```bash
# As superuser
docker compose exec postgres psql -U postgres -d reliant_main

# As n8n user
docker compose exec postgres psql -U n8n_user -d reliant_main
```

### Check Database Size

```bash
docker compose exec postgres psql -U postgres -c "SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) AS size FROM pg_database;"
```

## Troubleshooting

### Service Won't Start

```bash
# Check logs for errors
docker compose logs <service-name>

# Check if ports are already in use
sudo netstat -tlnp | grep -E '5679|3002'
```

### Database Connection Issues

```bash
# Verify postgres is healthy
docker compose exec postgres pg_isready -U postgres

# Check network connectivity
docker compose exec n8n ping postgres
```

### n8n Webhook Issues

Ensure these are properly configured:
- Caddy is properly forwarding `temp.reliantcleanandrepair.com` to `127.0.0.1:5679`
- DNS points to your VPS IP
- SSL certificate is valid (Caddy handles this automatically)

### Reset n8n Admin Password

```bash
docker compose exec n8n n8n user:reset --email=admin@example.com
```

## File Structure

```
/opt/reliant-stack/
├── docker-compose.yml       # Main Docker Compose configuration
├── .env                     # Environment variables (DO NOT COMMIT)
├── .env.example            # Template for environment variables
├── init-db.sh              # PostgreSQL initialization script
├── backup-script.sh        # Automated backup script
├── postgres-backups/       # Local backup storage
└── README.md               # This file
```

## Security Considerations

1. **Never commit `.env`** to version control
2. Use **strong, unique passwords** for all credentials
3. Regularly update Docker images: `docker compose pull && docker compose up -d`
4. Monitor backup logs: `docker compose logs postgres-backup`
5. Test restore procedures periodically
6. Keep host system updated: `sudo apt update && sudo apt upgrade`
7. Consider implementing **fail2ban** for SSH protection
8. Use **offsite backups** - local backups are not sufficient

## Network Configuration

- **Network Name**: `reliant-network`
- **Driver**: bridge (isolated from host)
- **Exposed Ports**: Only `127.0.0.1:5679` and `127.0.0.1:3002` (localhost only)
- **Port 80/443**: NOT used (Caddy on host handles SSL/TLS)

## Volume Information

All data is stored in named Docker volumes:

- `reliant-postgres-data`: PostgreSQL database files
- `reliant-n8n-data`: n8n workflows, credentials, and settings
- `reliant-uptime-kuma-data`: Uptime Kuma configuration and monitoring data

Backups are stored in the mounted directory: `./postgres-backups/`

## Support & Additional Resources

- **n8n Documentation**: https://docs.n8n.io
- **Uptime Kuma**: https://github.com/louislam/uptime-kuma
- **PostgreSQL**: https://www.postgresql.org/docs/
- **Docker Compose**: https://docs.docker.com/compose/

## License

Configure according to your organization's requirements.
# Production-web-deploy
