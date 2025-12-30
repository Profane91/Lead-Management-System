# Example Stack - Complete Lead Management System

Production-ready VPS stack for lead capture, processing, and management with automated workflows, spam protection, and multi-channel notifications.

## 🎯 What This Does

Complete lead management pipeline:
1. **Website Form** (Astro) → Customer submits inquiry
2. **Cloudflare Worker** → Validates, filters spam, enforces CORS
3. **n8n Workflow** → Processes lead, stores in database
4. **PostgreSQL** → Secure lead storage with client management
5. **Notifications** → SMS (Twilio) + Email (SMTP) to business owner
6. **Auto-Reply** → Instant confirmation to customer

## 🚀 Quick Start

```bash
# 1. Clone repository
git clone <your-repo-url> example-stack
cd example-stack

# 2. Configure environment
cp .env.example .env
nano .env  # Add your credentials

# 3. Generate secure keys
openssl rand -hex 32  # For N8N_ENCRYPTION_KEY
openssl rand -hex 32  # For N8N_JWT_SECRET

# 4. Start services
docker compose up -d

# 5. Initialize database
docker exec -i example_postgres psql -U <user> -d <db> < n8n-lead-workflow/schema.sql
```

**📚 Full setup guide:** See [SETUP.md](SETUP.md) for complete step-by-step instructions.

## 📦 Components

### Core Infrastructure (`docker-compose.yml`)
- **PostgreSQL 16**: Lead database with automated backups
- **n8n**: Workflow automation platform
- **Uptime Kuma**: Service monitoring dashboard

### Astro Service Website (`astro-service-site/`)
- Config-driven business website (single JSON source)
- Mobile-responsive design with CTAs
- Contact form with UTM tracking and honeypot spam protection
- Cloudflare Pages deployment ready

### Cloudflare Worker (`worker-lead-gateway/`)
- Lead validation and spam filtering
- CORS enforcement
- Request forwarding to n8n webhook
- Shared secret authentication

### n8n Workflow (`n8n-lead-workflow/`)
- Database schema with client management
- Lead processing workflow (simple version included)
- Expandable for SMS/email notifications
- Auto-reply system support

## 🏗️ Architecture

```
┌─────────────────┐
│  Astro Website  │
│  (Static HTML)  │
└────────┬────────┘
         │ POST /submit
         ↓
┌─────────────────────┐
│ Cloudflare Worker   │
│ • Validation        │
│ • Spam Check        │
│ • CORS              │
└────────┬────────────┘
         │ POST /webhook/lead
         ↓
┌─────────────────────┐
│      n8n            │
│ • Normalize Data    │
│ • Insert Database   │
│ • Send Notifications│
└────────┬────────────┘
         ↓
┌─────────────────────┐
│    PostgreSQL       │
│ • clients table     │
│ • leads table       │
│ • Automated backups │
└─────────────────────┘
```

## 🛠️ Setup Requirements

- **Server**: Ubuntu 20.04+ VPS (2GB RAM minimum)
- **Software**: Docker, Docker Compose V2, Caddy
- **Domain**: DNS configured for n8n and monitoring
- **Cloudflare**: Account for Worker and Pages deployment
- **Optional**: Twilio (SMS), SMTP credentials (email)

## 📖 Documentation

| Document | Description |
|----------|-------------|
| [SETUP.md](SETUP.md) | Complete step-by-step installation guide |
| [DEPLOYMENT.md](DEPLOYMENT.md) | Architecture, configuration, troubleshooting |
| [docs/ONBOARDING.md](docs/ONBOARDING.md) | Guide for adding new clients |
| [astro-service-site/README.md](astro-service-site/README.md) | Website customization |
| [worker-lead-gateway/README.md](worker-lead-gateway/README.md) | Worker deployment |
| [n8n-lead-workflow/README.md](n8n-lead-workflow/README.md) | Workflow setup |

## ⚡ Features

### Lead Management
- ✅ Multi-client support with separate configurations
- ✅ Full lead history with source tracking
- ✅ UTM campaign tracking
- ✅ Raw request data preservation (JSONB)
- ✅ Automated database cleanup

### Security
- ✅ Shared secret authentication between Worker and n8n
- ✅ CORS origin validation
- ✅ Honeypot spam detection
- ✅ Input validation and sanitization
- ✅ PostgreSQL prepared statements (SQL injection prevention)

### Notifications
- ✅ Configurable SMS alerts (Twilio)
- ✅ Configurable email notifications (SMTP)
- ✅ Auto-reply to customers
- ✅ Template variable support
- ✅ Per-client notification preferences

### Operations
- ✅ Automated daily PostgreSQL backups
- ✅ Backup retention policy (configurable)
- ✅ Health checks on all services
- ✅ Uptime monitoring dashboard
- ✅ Docker log aggregation

## 🧪 Testing

Test the complete pipeline:

```bash
curl -X POST https://your-worker.workers.dev/submit \
  -H "Content-Type: application/json" \
  -H "Origin: https://yourdomain.com" \
  -d '{
    "client_id": "your-client-id",
    "name": "Test Customer",
    "email": "test@example.com",
    "phone": "555-123-4567",
    "service": "Test Service",
    "message": "Testing pipeline",
    "source": "website"
  }'

# Verify in database
docker exec example_postgres psql -U user -d db \
  -c "SELECT * FROM leads ORDER BY created_at DESC LIMIT 1;"
```

## 🔒 Security Best Practices

- Never commit `.env` file to version control
- Use strong passwords (20+ characters, random)
- Rotate `N8N_ENCRYPTION_KEY` and `N8N_JWT_SECRET` every 90 days
- Keep Docker images updated monthly
- Monitor n8n execution logs regularly
- Use Cloudflare WAF rules for Worker protection
- Limit PostgreSQL access to Docker network only

## 📊 Monitoring & Maintenance

### Daily
- Check Uptime Kuma dashboard for service health
- Review n8n execution logs for errors

### Weekly
- Verify backups are running (`ls -la postgres-backups/`)
- Review lead volume and conversion sources

### Monthly
- Update Docker images: `docker compose pull && docker compose up -d`
- Clean old backups beyond retention period
- Review and update Worker configuration

## 🐛 Troubleshooting

### Worker returns 502
- Verify n8n is accessible: `curl https://your-n8n-domain.com/health`
- Check n8n workflow is activated
- Review Worker secrets are set correctly

### Leads not appearing in database
- Check n8n Executions tab for errors
- Verify PostgreSQL credential in n8n
- Test n8n webhook directly with curl

### n8n workflow fails
- Check PostgreSQL is running: `docker compose ps postgres`
- Verify database schema installed: `docker exec example_postgres psql -U user -d db -c "\dt"`
- Review n8n logs: `docker compose logs n8n`

See [DEPLOYMENT.md](DEPLOYMENT.md#-troubleshooting) for more solutions.

## 🤝 Contributing

This is a template project. Fork and customize for your needs!

## 📄 License

MIT License - See LICENSE file for details.

## 🆘 Support

1. Check documentation in `/docs`
2. Review troubleshooting guides
3. Inspect Docker logs: `docker compose logs`
4. Check n8n execution history
5. Review Cloudflare Worker logs: `npx wrangler tail`

---

**Made with ❤️ for service businesses that need reliable lead management**

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
   0 3 * * * rsync -az /opt/example-stack/postgres-backups/ user@backup-server:/backups/example-stack/
   ```

2. **Cloud Storage (rclone)**:
   ```bash
   # Install rclone and configure cloud provider
   sudo apt install rclone
   rclone config
   
   # Add to crontab
   0 3 * * * rclone sync /opt/example-stack/postgres-backups/ remote:example-backups/
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
docker compose exec postgres psql -U postgres -d example_main

# As n8n user
docker compose exec postgres psql -U n8n_user -d example_main
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
- Caddy is properly forwarding `temp.example.com` to `127.0.0.1:5679`
- DNS points to your VPS IP
- SSL certificate is valid (Caddy handles this automatically)

### Reset n8n Admin Password

```bash
docker compose exec n8n n8n user:reset --email=admin@example.com
```

## File Structure

```
/opt/example-stack/
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

- **Network Name**: `example-network`
- **Driver**: bridge (isolated from host)
- **Exposed Ports**: Only `127.0.0.1:5679` and `127.0.0.1:3002` (localhost only)
- **Port 80/443**: NOT used (Caddy on host handles SSL/TLS)

## Volume Information

All data is stored in named Docker volumes:

- `example-postgres-data`: PostgreSQL database files
- `example-n8n-data`: n8n workflows, credentials, and settings
- `example-uptime-kuma-data`: Uptime Kuma configuration and monitoring data

Backups are stored in the mounted directory: `./postgres-backups/`

## Support & Additional Resources

- **n8n Documentation**: https://docs.n8n.io
- **Uptime Kuma**: https://github.com/louislam/uptime-kuma
- **PostgreSQL**: https://www.postgresql.org/docs/
- **Docker Compose**: https://docs.docker.com/compose/

## License

Configure according to your organization's requirements.
# Production-web-deploy
