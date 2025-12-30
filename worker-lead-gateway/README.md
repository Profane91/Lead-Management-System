# Worker Lead Gateway

Cloudflare Workers-based lead capture gateway with spam protection, validation, and n8n webhook forwarding.

## Features

- ✅ **POST /submit** endpoint for form submissions
- ✅ Accepts multiple content types: JSON, form-urlencoded, multipart/form-data
- ✅ Honeypot spam protection
- ✅ Field validation with length checks
- ✅ Origin allowlist for CORS security
- ✅ Forwards validated leads to n8n webhook
- ✅ Adds metadata (IP, user agent, timestamp)
- ✅ 302 redirect to thank you page on success
- ✅ Health check endpoint at /health

## Project Structure

```
worker-lead-gateway/
├── src/
│   └── index.ts          # Main worker code
├── package.json          # Dependencies and scripts
├── tsconfig.json         # TypeScript configuration
├── wrangler.toml         # Cloudflare Workers configuration
└── README.md            # This file
```

## Local Development

### Prerequisites

- Node.js 18+ installed
- npm or pnpm
- Cloudflare account

### Setup

```bash
# Navigate to the project directory
cd worker-lead-gateway

# Install dependencies
npm install

# Authenticate with Cloudflare (one time)
npx wrangler login

# Get your account ID
npx wrangler whoami
```

Update `wrangler.toml` with your `account_id`.

### Run Locally

```bash
# Start local development server
npm run dev
```

The worker will be available at `http://localhost:8787`

### Test Locally

```bash
# Test with curl
curl -X POST http://localhost:8787/submit \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "reliant",
    "name": "John Doe",
    "phone": "5551234567",
    "email": "john@example.com",
    "message": "I need cleaning services",
    "source": "website"
  }'

# Health check
curl http://localhost:8787/health
```

## Environment Variables

Set these as secrets in Cloudflare Workers:

### N8N_WEBHOOK_URL
The n8n webhook endpoint that will receive the lead data.

Example: `https://temp.reliantcleanandrepair.com/webhook/lead-intake`

### WORKER_SHARED_SECRET
A secret key used to authenticate requests to n8n.

Generate with:
```bash
openssl rand -hex 32
```

### ALLOWED_ORIGINS
Comma-separated list of allowed origins for CORS.

Example: `https://reliantcleanandrepair.com,https://www.reliantcleanandrepair.com`

For local development, include: `http://localhost:4321`

## Setting Environment Variables

### Option 1: Using wrangler secret (Recommended for Production)

```bash
# For production environment
npx wrangler secret put N8N_WEBHOOK_URL --env production
# Enter: https://temp.reliantcleanandrepair.com/webhook/lead-intake

npx wrangler secret put WORKER_SHARED_SECRET --env production
# Enter: your-generated-secret-key

npx wrangler secret put ALLOWED_ORIGINS --env production
# Enter: https://reliantcleanandrepair.com,https://www.reliantcleanandrepair.com
```

### Option 2: Using .dev.vars for Local Development

Create a `.dev.vars` file in the project root (gitignored):

```env
N8N_WEBHOOK_URL=https://temp.reliantcleanandrepair.com/webhook/test-lead
WORKER_SHARED_SECRET=test-secret-key
ALLOWED_ORIGINS=http://localhost:4321,http://localhost:8787
```

## Deployment

### Deploy to Staging

```bash
npm run deploy:staging
```

### Deploy to Production

```bash
npm run deploy:production
```

### Deploy Default Environment

```bash
npm run deploy
```

### Verify Deployment

```bash
# Check if worker is live
curl https://lead-gateway.<YOUR_SUBDOMAIN>.workers.dev/health

# View real-time logs
npm run tail:production
```

## Complete Deployment Workflow

### 1. Install Dependencies

```bash
cd worker-lead-gateway
npm install
```

### 2. Update Configuration

Edit `wrangler.toml`:
- Set your `account_id`
- Verify environment names

### 3. Set Production Secrets

```bash
# N8N Webhook URL
npx wrangler secret put N8N_WEBHOOK_URL --env production
# Enter: https://temp.reliantcleanandrepair.com/webhook/lead-intake

# Shared Secret (generate first: openssl rand -hex 32)
npx wrangler secret put WORKER_SHARED_SECRET --env production
# Enter: <your-generated-secret>

# Allowed Origins
npx wrangler secret put ALLOWED_ORIGINS --env production
# Enter: https://reliantcleanandrepair.com,https://www.reliantcleanandrepair.com
```

### 4. Deploy to Production

```bash
npm run deploy:production
```

### 5. Get Worker URL

After deployment, Wrangler will output the worker URL:
```
https://lead-gateway.<YOUR_SUBDOMAIN>.workers.dev
```

### 6. Update Astro Site

Update `src/content/client.json` in your Astro project:

```json
{
  "leadEndpoint": "https://lead-gateway.<YOUR_SUBDOMAIN>.workers.dev/submit"
}
```

Or use a custom domain (see below).

## Custom Domain Setup

### Option 1: Workers Route (Recommended)

1. Go to Cloudflare Dashboard → Workers & Pages → your worker
2. Click **Triggers** → **Add Custom Domain**
3. Enter: `api.reliantcleanandrepair.com`
4. Cloudflare auto-configures DNS and SSL

Update Astro site:
```json
{
  "leadEndpoint": "https://api.reliantcleanandrepair.com/submit"
}
```

### Option 2: Workers Route on Existing Domain

1. Go to **Triggers** → **Add Route**
2. Route: `reliantcleanandrepair.com/api/*`
3. Zone: Select your domain
4. Worker: lead-gateway

Update Astro site:
```json
{
  "leadEndpoint": "https://reliantcleanandrepair.com/api/submit"
}
```

## API Reference

### POST /submit

Submit a lead form.

**Request Headers:**
- `Content-Type`: `application/json`, `application/x-www-form-urlencoded`, or `multipart/form-data`
- `Origin`: Must be in ALLOWED_ORIGINS list

**Request Body:**

```json
{
  "client_id": "reliant",
  "name": "John Doe",
  "phone": "5551234567",
  "email": "john@example.com",
  "message": "I need help with...",
  "service": "Deep Cleaning",
  "source": "website",
  "utm": "utm_source=google&utm_medium=cpc",
  "website": ""
}
```

**Required Fields:**
- `client_id` (string): Client identifier
- `name` (string, min 2 chars): Customer name
- `phone` (string, min 7 chars): Phone number
- `message` (string, max 2000 chars): Message/description

**Optional Fields:**
- `email` (string): Email address (validated if provided)
- `service` (string): Service interested in
- `source` (string): Traffic source
- `utm` (string): Packed UTM parameters
- `website` (string): Honeypot field (must be empty)

**Success Response:**
- Status: `302 Found`
- Location: `/thanks` (or origin + `/thanks`)

**Error Responses:**
- `400 Bad Request`: Invalid data or missing required fields
- `403 Forbidden`: Origin not allowed
- `502 Bad Gateway`: n8n webhook unreachable

### GET /health

Health check endpoint.

**Response:**
```json
{
  "status": "ok",
  "timestamp": "2025-12-28T18:00:00.000Z"
}
```

## n8n Webhook Configuration

Your n8n webhook will receive:

```json
{
  "client_id": "reliant",
  "name": "John Doe",
  "phone": "5551234567",
  "email": "john@example.com",
  "message": "I need cleaning services",
  "service": "Deep Cleaning",
  "source": "website",
  "utm": "utm_source=google&utm_medium=cpc",
  "ip": "192.0.2.1",
  "user_agent": "Mozilla/5.0...",
  "timestamp": "2025-12-28T18:00:00.000Z"
}
```

**Headers:**
- `X-Lead-Secret`: Your WORKER_SHARED_SECRET

**n8n Setup:**
1. Create a webhook node in n8n
2. Set path to something like `/webhook/lead-intake`
3. Method: POST
4. Authentication: None (use X-Lead-Secret header in subsequent nodes)
5. Full URL becomes: `https://temp.reliantcleanandrepair.com/webhook/lead-intake`

## Monitoring

### View Logs

```bash
# Real-time logs
npm run tail:production

# Filter logs
npx wrangler tail --env production --format pretty
```

### Metrics

View in Cloudflare Dashboard:
- Workers & Pages → your worker → Metrics
- Requests, errors, CPU time, and more

### Debugging

Enable debug mode in development:

```bash
# Local dev with verbose output
npx wrangler dev --local --log-level debug
```

## Security Best Practices

1. **Rotate Secrets Regularly**: Update WORKER_SHARED_SECRET periodically
2. **Use HTTPS Only**: Never allow HTTP origins in production
3. **Monitor for Abuse**: Set up rate limiting if needed (Cloudflare Enterprise)
4. **Validate n8n Responses**: Check response status codes
5. **Keep Dependencies Updated**: Run `npm update` regularly

## Troubleshooting

### CORS Errors

Ensure ALLOWED_ORIGINS includes the exact origin:
- Include protocol: `https://`
- Include subdomain: `www.` if used
- No trailing slash

### n8n Not Receiving Leads

1. Check n8n webhook URL is correct
2. Verify X-Lead-Secret header in n8n
3. Check worker logs: `npm run tail:production`
4. Test n8n webhook directly with curl

### Worker Not Deploying

```bash
# Check authentication
npx wrangler whoami

# Re-authenticate if needed
npx wrangler login

# Verify account ID
npx wrangler whoami
```

### Environment Variables Not Working

```bash
# List all secrets
npx wrangler secret list --env production

# Delete and recreate if needed
npx wrangler secret delete N8N_WEBHOOK_URL --env production
npx wrangler secret put N8N_WEBHOOK_URL --env production
```

## Cost Estimate

Cloudflare Workers Pricing (as of 2025):

**Free Tier:**
- 100,000 requests/day
- Perfect for small businesses

**Paid Plan ($5/month):**
- 10 million requests/month included
- $0.50 per additional million

For a service business receiving 50-100 leads/month, the free tier is sufficient.

## License

MIT License - Feel free to use for commercial projects

## Support

- Cloudflare Workers Docs: https://developers.cloudflare.com/workers/
- Wrangler CLI Docs: https://developers.cloudflare.com/workers/wrangler/
- n8n Docs: https://docs.n8n.io/

---

Built for Reliant Clean & Repair 🚀
