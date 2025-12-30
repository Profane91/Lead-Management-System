# Example Stack - Complete Lead Management System

Production-ready VPS stack for lead capture, processing, and management with n8n workflow automation, Cloudflare Workers gateway, Astro website, PostgreSQL database, and Uptime Kuma monitoring.

## 🏗️ Architecture

```
Website Form (Astro)
    ↓
Cloudflare Worker (Validation & Spam Protection)
    ↓
n8n Webhook (Lead Processing)
    ↓
PostgreSQL Database (Lead Storage)
    ↓
Notifications (SMS via Twilio / Email via SMTP)
```

## 📦 Components

- **`docker-compose.yml`**: Core infrastructure (PostgreSQL, n8n, Uptime Kuma, automated backups)
- **`astro-service-site/`**: Config-driven service business website template
- **`worker-lead-gateway/`**: Cloudflare Worker for lead capture with spam protection
- **`n8n-lead-workflow/`**: Database schema and workflow for lead processing
- **`docs/`**: Client onboarding and deployment documentation

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose V2
- Caddy reverse proxy (for HTTPS)
- Cloudflare account (for Worker deployment)
- Domain with DNS configured

### 1. Environment Setup

```bash
# Copy and configure environment variables
cp .env.example .env
nano .env
```

**Required changes in `.env`:**
- `POSTGRES_PASSWORD`: Strong password
- `N8N_ENCRYPTION_KEY`: `openssl rand -hex 32`
- `N8N_JWT_SECRET`: `openssl rand -hex 32`
- `N8N_HOST`: Your n8n domain (e.g., `n8n.yourdomain.com`)
- `WEBHOOK_URL`: Same as N8N_HOST with https://

### 2. Start Docker Stack

```bash
# Create backup directory
mkdir -p postgres-backups

# Start all services
docker compose up -d

# Verify services are running
docker compose ps
```

### 3. Initialize Database

```bash
# Install lead management schema
docker exec -i example_postgres psql -U postgres -d your_database_name < n8n-lead-workflow/schema.sql
```

### 4. Configure Caddy Reverse Proxy

Add to your Caddyfile:

```caddy
# n8n
n8n.yourdomain.com {
    reverse_proxy localhost:5679
}

# Uptime Kuma
monitor.yourdomain.com {
    reverse_proxy localhost:3002
}
```

Reload Caddy:
```bash
sudo caddy reload
```

### 5. Import n8n Workflow

1. Access n8n at `https://n8n.yourdomain.com`
2. Create initial admin account
3. Go to **Settings** → **Credentials** → Add PostgreSQL credential:
   - Host: `postgres`
   - Database: (from .env)
   - User: (from .env)
   - Password: (from .env)
   - Port: `5432`
4. Go to **Workflows** → **Import from File**
5. Select `n8n-lead-workflow/workflow-simple.json`
6. Assign PostgreSQL credential to "Insert Lead" node
7. **Activate** the workflow

### 6. Deploy Cloudflare Worker

```bash
cd worker-lead-gateway

# Login to Cloudflare
npx wrangler login

# Update wrangler.toml with your account ID
# Get it with: npx wrangler whoami

# Set production secrets
echo "https://n8n.yourdomain.com/webhook/lead" | npx wrangler secret put N8N_WEBHOOK_URL --env production
echo "your-shared-secret-here" | npx wrangler secret put WORKER_SHARED_SECRET --env production
echo "https://yourdomain.com" | npx wrangler secret put ALLOWED_ORIGINS --env production

# Deploy
npm run deploy:production
```

### 7. Deploy Astro Website

```bash
cd astro-service-site

# Update src/content/client.json with your business info

# Build
npm install
npm run build

# Deploy to Cloudflare Pages
npx wrangler pages deploy dist --project-name your-project-name
```

## 📚 Documentation

- **[Onboarding Guide](docs/ONBOARDING.md)**: Step-by-step guide for adding new clients
- **[Astro Site README](astro-service-site/README.md)**: Website configuration and customization
- **[Worker README](worker-lead-gateway/README.md)**: Lead gateway deployment and configuration
- **[n8n Workflow README](n8n-lead-workflow/README.md)**: Workflow setup and customization

## 🔧 Configuration

### Lead Workflow Customization

Edit `n8n-lead-workflow/schema.sql` to update client settings:

```sql
-- Update business info, notification preferences, auto-reply messages
UPDATE clients SET
  business_name = 'Your Business Name',
  owner_phone = '+15551234567',
  owner_email = 'owner@yourbusiness.com',
  notify_sms = true,
  notify_email = true,
  auto_reply_enabled = true
WHERE client_id = 'your-client-id';
```

### Website Customization

Edit `astro-service-site/src/content/client.json` - all content is driven from this single file.

### Worker Security

The Worker validates:
- CORS origin checking
- Honeypot spam detection
- Shared secret authentication
- Input validation (length, format)

## 🛠️ Maintenance

### Backups

Automated daily backups run at 2 AM (configurable in `.env`):
- Location: `./postgres-backups/`
- Retention: 7 days (configurable)
- Manual backup: `docker compose exec postgres-backup /backup.sh`

### Monitoring

- **Uptime Kuma**: Monitor all services at `https://monitor.yourdomain.com`
- **Docker logs**: `docker compose logs -f`
- **Worker logs**: `cd worker-lead-gateway && npx wrangler tail --env production`

### Database Access

```bash
# PostgreSQL shell
docker exec -it example_postgres psql -U postgres -d your_database_name

# View recent leads
SELECT id, name, email, phone, service, created_at FROM leads ORDER BY created_at DESC LIMIT 10;

# View clients
SELECT client_id, business_name, notify_sms, notify_email FROM clients;
```

## 🧪 Testing

### Test Complete Pipeline

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
    "message": "Test message",
    "source": "website"
  }'
```

### Verify Lead in Database

```bash
docker exec example_postgres psql -U postgres -d your_database_name \
  -c "SELECT * FROM leads ORDER BY created_at DESC LIMIT 1;"
```

## 📝 Environment Variables Reference

| Variable | Description | Example |
|----------|-------------|---------|
| `POSTGRES_PASSWORD` | PostgreSQL superuser password | Strong random password |
| `N8N_ENCRYPTION_KEY` | n8n encryption key | Output of `openssl rand -hex 32` |
| `N8N_JWT_SECRET` | n8n JWT secret | Output of `openssl rand -hex 32` |
| `N8N_HOST` | n8n domain | `n8n.yourdomain.com` |
| `WEBHOOK_URL` | n8n webhook base URL | `https://n8n.yourdomain.com/` |

See `.env.example` for complete list.

## 🆘 Troubleshooting

### n8n workflow failing
- Check PostgreSQL credential is configured
- Verify database schema is installed
- Check logs: `docker compose logs n8n`

### Worker returning 502
- Verify n8n webhook URL is correct
- Check n8n workflow is activated
- Verify CORS origins in Worker secrets

### No leads in database
- Check n8n Executions tab for errors
- Verify PostgreSQL node has correct query parameters
- Test n8n webhook directly with curl

## 📄 License

MIT

## 🤝 Contributing

This is a template project. Feel free to fork and customize for your needs.
