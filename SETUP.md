# Setup Instructions

Complete setup guide for deploying the Reliant Stack lead management system.

## Prerequisites Checklist

- [ ] VPS with Ubuntu 20.04+ (2GB RAM minimum, 4GB recommended)
- [ ] Docker and Docker Compose V2 installed
- [ ] Domain with DNS configured
- [ ] Caddy installed and running
- [ ] Cloudflare account
- [ ] (Optional) Twilio account for SMS
- [ ] (Optional) SMTP credentials for email

## Step-by-Step Setup

### 1. Initial Server Setup

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Caddy
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy

# Logout and login for Docker group to take effect
```

### 2. Clone and Configure Project

```bash
# Clone to /opt (recommended) or your preferred location
cd /opt
git clone <your-repo-url> reliant-stack
cd reliant-stack

# Copy and edit environment file
cp .env.example .env
nano .env
```

### 3. Generate Secure Keys

```bash
# Generate encryption key
echo "N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)"

# Generate JWT secret
echo "N8N_JWT_SECRET=$(openssl rand -hex 32)"

# Generate Worker shared secret
echo "WORKER_SHARED_SECRET=$(openssl rand -hex 32)"

# Copy these values into your .env file
```

### 4. Configure .env File

Edit `.env` with your values:

```bash
# PostgreSQL
POSTGRES_DB=your_db_name
POSTGRES_USER=your_user
POSTGRES_PASSWORD=<strong-password>

# n8n
N8N_DB_NAME=your_db_name
N8N_DB_USER=your_user  
N8N_DB_PASSWORD=<same-as-postgres-password>
N8N_ENCRYPTION_KEY=<from-step-3>
N8N_JWT_SECRET=<from-step-3>
N8N_HOST=n8n.yourdomain.com
WEBHOOK_URL=https://n8n.yourdomain.com/
```

### 5. Configure DNS

Point these domains to your VPS IP:

- `n8n.yourdomain.com` → Your VPS IP
- `monitor.yourdomain.com` → Your VPS IP (for Uptime Kuma)
- `www.yourdomain.com` → Cloudflare Pages (later)

### 6. Configure Caddy

Edit `/etc/caddy/Caddyfile`:

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

### 7. Start Docker Stack

```bash
# Create backup directory
mkdir -p postgres-backups

# Start services
docker compose up -d

# Wait 30 seconds for services to initialize
sleep 30

# Check status
docker compose ps

# Check logs
docker compose logs -f
```

All services should show "Up" status.

### 8. Initialize Database

```bash
# Install lead management schema
docker exec -i reliant_postgres psql -U <your-postgres-user> -d <your-db-name> < n8n-lead-workflow/schema.sql

# Verify tables were created
docker exec reliant_postgres psql -U <your-postgres-user> -d <your-db-name> -c "\dt"
```

You should see `clients` and `leads` tables.

### 9. Configure n8n

1. Open `https://n8n.yourdomain.com` in browser
2. Create admin account
3. **Create PostgreSQL Credential:**
   - Settings → Credentials → Add Credential
   - Type: "Postgres"
   - Name: "Reliant Database"
   - Host: `postgres`
   - Database: (from .env)
   - User: (from .env)
   - Password: (from .env)
   - Port: `5432`
   - SSL: `disable`
   - Save

4. **Import Workflow:**
   - Workflows → Add Workflow → Import from File
   - Select: `n8n-lead-workflow/workflow-simple.json`
   - Click on "Insert Lead" node
   - Select "Reliant Database" credential
   - **Activate workflow** (toggle in top right)

5. **Verify webhook URL:**
   - Click "Webhook" node
   - Note the Production URL: `https://n8n.yourdomain.com/webhook/lead`

### 10. Deploy Cloudflare Worker

```bash
cd worker-lead-gateway

# Install dependencies
npm install

# Login to Cloudflare
npx wrangler login

# Get your account ID
npx wrangler whoami

# Update wrangler.toml with your account ID
nano wrangler.toml
# Change: account_id = "YOUR_ACCOUNT_ID"

# Set production secrets
echo "https://n8n.yourdomain.com/webhook/lead" | npx wrangler secret put N8N_WEBHOOK_URL --env production
echo "<your-shared-secret-from-step-3>" | npx wrangler secret put WORKER_SHARED_SECRET --env production  
echo "https://yourdomain.com,https://www.yourdomain.com" | npx wrangler secret put ALLOWED_ORIGINS --env production

# Deploy
npm run deploy:production

# Note the Worker URL (e.g., https://lead-gateway.yourname.workers.dev)
```

### 11. Deploy Astro Website

```bash
cd astro-service-site

# Install dependencies
npm install

# Configure client info
nano src/content/client.json
# Update with your business information

# Build
npm run build

# Deploy to Cloudflare Pages
npx wrangler pages deploy dist --project-name your-business-name

# Or connect GitHub repository in Cloudflare dashboard
```

### 12. Update Website Form

In your deployed Astro site, update the contact form action:

```html
<form action="https://lead-gateway.yourname.workers.dev/submit" method="POST">
```

Or use the route you configured in Cloudflare Pages settings.

### 13. Test Complete Pipeline

```bash
# Test from command line
curl -X POST https://lead-gateway.yourname.workers.dev/submit \
  -H "Content-Type: application/json" \
  -H "Origin: https://yourdomain.com" \
  -d '{
    "client_id": "reliant",
    "name": "Test Customer",
    "email": "test@example.com",
    "phone": "555-123-4567",
    "service": "Test Service",
    "message": "Testing the pipeline",
    "source": "website"
  }'

# Verify lead in database
docker exec reliant_postgres psql -U <your-postgres-user> -d <your-db-name> \
  -c "SELECT id, name, email, phone, service, created_at FROM leads ORDER BY created_at DESC LIMIT 1;"
```

You should see the test lead in the database.

### 14. Configure Uptime Kuma (Optional)

1. Open `https://monitor.yourdomain.com`
2. Create admin account
3. Add monitors for:
   - n8n (https://n8n.yourdomain.com)
   - Worker (your Worker URL)
   - Website (https://yourdomain.com)
   - PostgreSQL (Docker internal check)

## Post-Setup

### Add SMS Notifications (Optional)

1. Get Twilio credentials
2. In n8n:
   - Settings → Credentials → Add "Twilio"
   - Add Account SID and Auth Token
3. Import full workflow: `n8n-lead-workflow/workflow.json`
4. Configure Twilio nodes
5. Activate workflow

### Add Email Notifications (Optional)

1. Get SMTP credentials
2. In n8n:
   - Settings → Credentials → Add "SMTP"
   - Configure SMTP settings
3. Configure email nodes in workflow
4. Activate workflow

### Update Client Settings

```bash
docker exec -it reliant_postgres psql -U <your-user> -d <your-db>

# Update client notification preferences
UPDATE clients SET
  business_name = 'Your Business Name',
  owner_phone = '+15551234567',
  owner_email = 'owner@yourbusiness.com',
  notify_sms = true,
  notify_email = true,
  auto_reply_enabled = true
WHERE client_id = 'reliant';
```

## Verification Checklist

- [ ] Docker containers all running (`docker compose ps`)
- [ ] PostgreSQL accessible and schema installed
- [ ] n8n accessible at your domain
- [ ] n8n workflow imported and activated
- [ ] Cloudflare Worker deployed and responding
- [ ] Astro website deployed
- [ ] Test lead successfully reaches database
- [ ] Uptime Kuma monitoring configured
- [ ] Backups running (check `./postgres-backups/`)

## Troubleshooting

See [DEPLOYMENT.md](DEPLOYMENT.md#-troubleshooting) for common issues and solutions.

## Maintenance

### Daily Tasks
- Check Uptime Kuma for alerts
- Review n8n execution logs

### Weekly Tasks
- Verify backups are being created
- Review lead volume and sources

### Monthly Tasks
- Update Docker images: `docker compose pull && docker compose up -d`
- Review and clean old backups
- Update Cloudflare Worker if needed

## Security Notes

- Never commit `.env` file to git
- Use strong passwords (20+ characters)
- Rotate secrets every 90 days
- Keep Docker images updated
- Monitor n8n access logs
- Use Cloudflare WAF rules for Worker

## Support

For issues or questions:
1. Check [DEPLOYMENT.md](DEPLOYMENT.md) troubleshooting section
2. Review Docker logs: `docker compose logs`
3. Check n8n Executions tab for workflow errors
4. Review Cloudflare Worker logs: `npx wrangler tail`
