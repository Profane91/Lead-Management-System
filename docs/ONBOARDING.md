# Client Onboarding Guide

Quick guide to add a new service business client to the Reliant Stack lead management system.

## Prerequisites

- Client domain (e.g., `newclient.com`)
- Client contact info (owner phone + email)
- Access to: Cloudflare, n8n, PostgreSQL

## Step 1: Clone and Configure Astro Site

### 1.1 Clone Template

```bash
cd /opt/reliant-stack
cp -r astro-service-site astro-newclient-site
cd astro-newclient-site
```

### 1.2 Update Configuration

Edit `src/content/client.json`:

```json
{
  "businessName": "NewClient Services",
  "tagline": "Your compelling tagline here",
  "positioning": "Brief positioning statement",
  "homepageBlurb": "Homepage description...",
  "brandLine": "Your brand promise",
  "phoneDisplay": "(555) 987-6543",
  "phoneE164": "+15559876543",
  "email": "hello@newclient.com",
  "serviceArea": "Greater Metropolitan Area",
  "clientId": "newclient",  // ⚠️ MUST be unique & lowercase
  "leadEndpoint": "https://lead-gateway.YOUR-SUBDOMAIN.workers.dev/submit",
  "sourceDefault": "website",
  "services": [
    {"title": "Service 1", "desc": "Description..."},
    {"title": "Service 2", "desc": "Description..."}
  ],
  "trustPoints": ["Point 1", "Point 2", "Point 3"],
  "faq": [
    {"q": "Question 1?", "a": "Answer 1"},
    {"q": "Question 2?", "a": "Answer 2"}
  ],
  "cta": {
    "primaryText": "Request a Quote",
    "primaryHref": "#contact",
    "secondaryText": "Call Now",
    "secondaryHref": "tel:+15559876543",
    "bookingText": "Book Online",
    "bookingHref": ""  // Leave empty or add booking URL
  }
}
```

### 1.3 Test Locally

```bash
npm install
npm run dev
# Visit http://localhost:4321
```

Verify all content displays correctly.

## Step 2: Deploy to Cloudflare Pages

### 2.1 Build Site

```bash
npm run build
# Check dist/ folder
```

### 2.2 Deploy via Git (Recommended)

```bash
cd astro-newclient-site
git init
git add .
git commit -m "Initial commit for NewClient"
git remote add origin https://github.com/yourusername/astro-newclient-site.git
git push -u origin main
```

In Cloudflare Dashboard:
1. **Workers & Pages** → **Create application** → **Pages**
2. **Connect to Git** → Select repository
3. **Build settings**:
   - Framework: Astro
   - Build command: `npm run build`
   - Build output: `dist`
4. **Save and Deploy**

### 2.3 Connect Custom Domain

1. Go to your Pages project → **Custom domains**
2. Click **Set up a custom domain**
3. Enter: `newclient.com` (and `www.newclient.com`)
4. Cloudflare auto-configures DNS and SSL

Wait 5-10 minutes for DNS propagation and SSL provisioning.

## Step 3: Update Cloudflare Worker

### 3.1 Add Client Domain to ALLOWED_ORIGINS

```bash
# Get current value
npx wrangler secret list --env production

# Update (append new domain)
npx wrangler secret put ALLOWED_ORIGINS --env production
# Enter: https://reliantcleanandrepair.com,https://newclient.com,https://www.newclient.com
```

**Important**: Include all protocols and subdomains (http/https, www/non-www).

### 3.2 Test Worker CORS

```bash
curl -X OPTIONS https://lead-gateway.YOUR-SUBDOMAIN.workers.dev/submit \
  -H "Origin: https://newclient.com" \
  -H "Access-Control-Request-Method: POST" \
  -v
```

Check for `Access-Control-Allow-Origin: https://newclient.com` in response.

## Step 4: Add Client to Database

### 4.1 Connect to PostgreSQL

```bash
docker compose exec postgres psql -U postgres -d reliant_main
```

### 4.2 Insert Client Record

```sql
INSERT INTO clients (
    client_id,
    business_name,
    owner_phone,
    owner_email,
    notify_sms,
    notify_email,
    auto_reply_enabled,
    auto_reply_sms,
    auto_reply_email_subject,
    auto_reply_email_body
) VALUES (
    'newclient',  -- ⚠️ MUST match clientId in client.json
    'NewClient Services',
    '+15559876543',  -- ⚠️ Owner's phone (E.164 format)
    'owner@newclient.com',  -- ⚠️ Owner's email
    true,  -- Send SMS notifications
    true,  -- Send email notifications
    true,  -- Enable auto-reply
    'Thank you for contacting NewClient Services! We received your request and will respond within 24 hours.',
    'Thank You for Contacting NewClient Services',
    'Hi {{name}},

Thank you for your inquiry about {{service}}.

We will review your request and get back to you within 24 hours.

Best regards,
NewClient Services Team'
);
```

### 4.3 Verify Insert

```sql
SELECT * FROM clients WHERE client_id = 'newclient';
```

Should show your new client record.

## Step 5: End-to-End Testing

### 5.1 Submit Test Lead

Visit the live site and fill out the contact form:
- **Name**: Test Customer
- **Phone**: Your test number
- **Email**: Your test email
- **Message**: Test inquiry for onboarding

Or use curl:

```bash
curl -X POST https://lead-gateway.YOUR-SUBDOMAIN.workers.dev/submit \
  -H "Content-Type: application/json" \
  -H "Origin: https://newclient.com" \
  -d '{
    "client_id": "newclient",
    "name": "Test Customer",
    "phone": "5551234567",
    "email": "test@example.com",
    "message": "Test inquiry",
    "source": "website"
  }'
```

### 5.2 Verify Flow

**✅ Astro Site**:
- Form submits without errors
- Redirects to `/thanks` page

**✅ Cloudflare Worker**:
```bash
npx wrangler tail --env production
# Should show POST /submit with 302 response
```

**✅ n8n**:
- Go to n8n → **Executions**
- Find latest execution of "Lead Intake" workflow
- Check all nodes succeeded (green checkmarks)

**✅ PostgreSQL**:
```sql
SELECT * FROM leads 
WHERE client_id = 'newclient' 
ORDER BY created_at DESC 
LIMIT 1;
```

**✅ Owner Notifications**:
- Check owner's phone for SMS
- Check owner's email inbox

**✅ Customer Auto-Reply** (if enabled):
- Check test phone for SMS
- Check test email inbox

## Step 6: Final Checklist

- [ ] `client.json` updated with unique `clientId`
- [ ] Astro site deployed to Cloudflare Pages
- [ ] Custom domain connected and SSL active
- [ ] Worker `ALLOWED_ORIGINS` includes new domain
- [ ] Client record exists in `clients` table
- [ ] Test lead inserted successfully
- [ ] Owner received SMS notification
- [ ] Owner received email notification
- [ ] Customer received auto-reply (if enabled)
- [ ] Form redirects to `/thanks` page
- [ ] No errors in n8n execution log

## Troubleshooting

### Problem: Form Submission Returns 403 Forbidden

**Cause**: Origin not in ALLOWED_ORIGINS

**Fix**:
```bash
npx wrangler secret put ALLOWED_ORIGINS --env production
# Include exact origin: https://newclient.com
```

Test CORS:
```bash
curl -X OPTIONS https://lead-gateway.workers.dev/submit \
  -H "Origin: https://newclient.com" \
  -v | grep -i "access-control"
```

### Problem: n8n Workflow Returns 401 Unauthorized

**Cause**: X-Lead-Secret mismatch

**Fix**: Ensure Worker's `WORKER_SHARED_SECRET` matches n8n's `LEAD_SECRET` env var.

```bash
# Worker side
npx wrangler secret put WORKER_SHARED_SECRET --env production

# n8n side (restart after changing)
docker compose restart n8n
```

### Problem: Lead Not Inserted in Database

**Cause**: client_id doesn't exist in clients table

**Fix**: Verify client record exists:
```sql
SELECT * FROM clients WHERE client_id = 'newclient';
```

If missing, insert as shown in Step 4.2.

### Problem: Owner Not Receiving Notifications

**SMS Issues**:
- Verify Twilio credentials in n8n
- Check phone format: E.164 (+15559876543)
- Check Twilio account balance
- Verify `notify_sms = true` in clients table

**Email Issues**:
- Verify SMTP credentials in n8n
- Check from/to addresses
- Check spam folder
- Verify `notify_email = true` in clients table

### Problem: Customer Auto-Reply Not Sending

**Fix**:
```sql
-- Check auto-reply settings
SELECT auto_reply_enabled, auto_reply_sms, auto_reply_email_subject 
FROM clients 
WHERE client_id = 'newclient';

-- Enable if needed
UPDATE clients 
SET auto_reply_enabled = true 
WHERE client_id = 'newclient';
```

### Problem: Form Shows Wrong leadEndpoint

**Cause**: `client.json` not updated or build not redeployed

**Fix**:
1. Update `leadEndpoint` in `client.json`
2. Rebuild: `npm run build`
3. Redeploy to Cloudflare Pages (auto if using Git)

### Debug Flow Step-by-Step

**1. Astro Form → Worker**:
```bash
# Browser DevTools → Network tab
# Check POST request to leadEndpoint
# Should return 302 to /thanks
```

**2. Worker → n8n**:
```bash
# View Worker logs
npx wrangler tail --env production

# Should show:
# POST /submit → 302 redirect
```

**3. n8n → PostgreSQL**:
```bash
# Check n8n execution
# Open workflow → Executions tab
# Click latest execution → verify all nodes green

# Check database
docker compose exec postgres psql -U postgres -d reliant_main
SELECT * FROM leads ORDER BY created_at DESC LIMIT 1;
```

**4. n8n → Twilio/SMTP**:
```bash
# In n8n execution:
# Click "Send SMS to Owner" node → check output
# Click "Send Email to Owner" node → check output
# If errors, check credentials
```

## Quick Reference

**Unique Identifiers Required**:
- `clientId` in `client.json` (lowercase, no spaces)
- Same value in PostgreSQL `clients.client_id`
- Must match in all lead submissions

**URLs**:
- Astro site: `https://newclient.com`
- Worker: `https://lead-gateway.YOUR-SUBDOMAIN.workers.dev/submit`
- n8n webhook: `https://temp.reliantcleanandrepair.com/webhook/lead-intake`

**Critical Environment Variables**:
- Worker: `ALLOWED_ORIGINS`, `N8N_WEBHOOK_URL`, `WORKER_SHARED_SECRET`
- n8n: `LEAD_SECRET`, `TWILIO_FROM_NUMBER`, `SMTP_FROM_EMAIL`

## Next Steps

After successful onboarding:

1. **Monitor Performance**:
   - Check n8n executions daily
   - Review lead conversion rates
   - Monitor SMS/email delivery

2. **Customize Templates**:
   - Update auto-reply messages per client
   - Adjust notification formats
   - Add client-specific fields

3. **Analytics**:
   ```sql
   -- Leads per day
   SELECT DATE(created_at), COUNT(*) 
   FROM leads 
   WHERE client_id = 'newclient' 
   GROUP BY DATE(created_at) 
   ORDER BY DATE(created_at) DESC;
   
   -- Leads by source
   SELECT source, COUNT(*) 
   FROM leads 
   WHERE client_id = 'newclient' 
   GROUP BY source;
   ```

4. **Backup**:
   - Enable automated database backups
   - Test restore procedure
   - Document custom configurations

---

**Need Help?** Check the main README files in each project directory for detailed documentation.
