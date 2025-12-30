# n8n Lead Management Workflow

Complete n8n workflow for handling leads from Cloudflare Worker with validation, database storage, and automated notifications.

## Contents

1. **schema.sql** - PostgreSQL database schema (clients + leads tables)
2. **workflow.json** - n8n workflow export (importable)
3. **README.md** - This documentation

## Overview

This workflow receives leads from the Cloudflare Worker, validates them, stores in PostgreSQL, and sends notifications to business owners via SMS and email. It also supports automated customer replies.

### Workflow Features

✅ **Webhook Trigger** - POST endpoint at `/webhook/lead-intake`  
✅ **Secret Validation** - Checks X-Lead-Secret header  
✅ **Data Normalization** - Trims, validates, and formats all fields  
✅ **Database Storage** - Inserts leads with full metadata  
✅ **Client Lookup** - Fetches notification settings per client  
✅ **Owner Notifications** - SMS + HTML email to business owner  
✅ **Auto-Reply** - Optional SMS + email to customer  
✅ **Template Variables** - Dynamic content replacement  
✅ **Parallel Processing** - Notifications sent concurrently  

## Database Setup

### 1. Connect to PostgreSQL

Using the Docker setup from `/opt/example-stack`:

```bash
# Access PostgreSQL container
docker compose exec postgres psql -U postgres -d example_main

# Or connect from host
psql -h localhost -p 5432 -U postgres -d example_main
```

### 2. Run Schema

```bash
# From file
docker compose exec -T postgres psql -U postgres -d example_main < /opt/example-stack/n8n-lead-workflow/schema.sql

# Or manually
docker compose exec postgres psql -U postgres -d example_main
\i /backups/schema.sql
```

### 3. Verify Tables

```sql
-- List tables
\dt

-- Check clients table
SELECT * FROM clients WHERE client_id = 'example';

-- Check leads table structure
\d leads
```

### 4. Update Seed Data

Edit `schema.sql` and update the INSERT statement with real contact info:

```sql
INSERT INTO clients (
    client_id, business_name, owner_phone, owner_email, ...
) VALUES (
    'example',
    'Example Business',
    '+15551234567',  -- ⚠️ CHANGE THIS
    'owner@example.com',  -- ⚠️ CHANGE THIS
    ...
);
```

## n8n Workflow Setup

### 1. Import Workflow

1. Log in to n8n: https://temp.example.com
2. Click **Workflows** → **Import from File**
3. Select `workflow.json`
4. Click **Import**

### 2. Configure Credentials

#### PostgreSQL Credential

1. Go to **Credentials** → **Add Credential** → **Postgres**
2. Name: `Postgres - Example`
3. Settings:
   ```
   Host: postgres (or example-postgres for Docker)
   Database: example_main
   User: n8n_user
   Password: <from .env N8N_DB_PASSWORD>
   Port: 5432
   SSL: Disable (internal network)
   ```
4. Test connection and save

#### Twilio Credential (SMS)

1. Go to **Credentials** → **Add Credential** → **Twilio**
2. Name: `Twilio`
3. Get credentials from: https://console.twilio.com/
   - Account SID
   - Auth Token
4. Save credential

#### SMTP Credential (Email)

Option A - Gmail:
```
Host: smtp.gmail.com
Port: 587
User: your-email@gmail.com
Password: App Password (not regular password)
From Email: your-email@gmail.com
```

Option B - Postmark:
```
Host: smtp.postmarkapp.com
Port: 587
User: <your-server-token>
Password: <your-server-token>
From Email: verified-sender@yourdomain.com
```

Option C - SendGrid:
```
Host: smtp.sendgrid.net
Port: 587
User: apikey
Password: <your-api-key>
From Email: verified-sender@yourdomain.com
```

### 3. Set Environment Variables

In n8n, set these environment variables:

#### Via Docker Environment

Edit `/opt/example-stack/.env`:

```env
# Lead workflow settings
LEAD_SECRET=your-secret-key-from-worker
TWILIO_FROM_NUMBER=+15551234567
SMTP_FROM_EMAIL=noreply@example.com
```

Then restart n8n:
```bash
docker compose restart n8n
```

#### Via n8n Settings (Alternative)

1. Go to workflow → Click gear icon → **Settings** → **Environment Variables**
2. Add:
   - `LEAD_SECRET`: Same as WORKER_SHARED_SECRET from Cloudflare Worker
   - `TWILIO_FROM_NUMBER`: Your Twilio phone number (E.164 format)
   - `SMTP_FROM_EMAIL`: Verified sender email

### 4. Update Node Credentials

After importing, update these nodes with your credentials:

1. **Insert Lead** node → Select `Postgres - Example` credential
2. **Lookup Client** node → Select `Postgres - Example` credential
3. **Send SMS to Owner** node → Select `Twilio` credential
4. **Send Auto-Reply SMS** node → Select `Twilio` credential
5. **Send Email to Owner** node → Select `SMTP` credential
6. **Send Auto-Reply Email** node → Select `SMTP` credential

### 5. Activate Workflow

1. Click **Active** toggle in top right
2. Copy webhook URL (e.g., `https://temp.example.com/webhook/lead-intake`)
3. Update Cloudflare Worker's `N8N_WEBHOOK_URL` environment variable

## Workflow Node Breakdown

### Node 1: Webhook Trigger
- **Type**: Webhook
- **Path**: `lead-intake`
- **Method**: POST
- **Response Mode**: Last Node
- **Purpose**: Receives lead data from Cloudflare Worker

### Node 2: Validate Secret
- **Type**: If (Conditional)
- **Condition**: `headers.x-lead-secret` equals `$env.LEAD_SECRET`
- **True**: Continue to Normalize Data
- **False**: Send 401 Unauthorized

### Node 3: Unauthorized Response
- **Type**: Respond to Webhook
- **Status**: 401
- **Body**: `{"error": "Unauthorized"}`
- **Purpose**: Block invalid requests

### Node 4: Normalize Data
- **Type**: Code (JavaScript)
- **Purpose**: 
  - Trim all string fields
  - Lowercase email
  - Set defaults for missing optional fields
  - Prepare raw_data for JSONB storage

### Node 5: Insert Lead
- **Type**: Postgres
- **Operation**: Execute Query
- **Query**: Parameterized INSERT into leads table
- **Returns**: lead ID and created_at timestamp

### Node 6: Lookup Client
- **Type**: Postgres
- **Operation**: Execute Query
- **Query**: SELECT client settings by client_id
- **Returns**: Notification preferences and auto-reply templates

### Node 7: Merge Data
- **Type**: Code (JavaScript)
- **Purpose**:
  - Combine lead data with client settings
  - Create message snippet (100 chars)
  - Parse UTM parameters
  - Prepare data for notifications

### Node 8-9: Check SMS Enabled → Send SMS to Owner
- **Condition**: `notify_sms == true` AND owner_phone exists
- **SMS Content**: Lead summary with name, phone, message snippet, source
- **To**: Owner's phone number

### Node 10-11: Check Email Enabled → Send Email to Owner
- **Condition**: `notify_email == true` AND owner_email exists
- **Email**: HTML formatted with complete lead details
- **To**: Owner's email address

### Node 12-13: Check Auto-Reply SMS → Send Auto-Reply SMS
- **Condition**: `auto_reply_enabled == true` AND customer phone exists
- **SMS Content**: Pre-configured auto-reply message from database
- **To**: Customer's phone number

### Node 14-16: Check Auto-Reply Email → Process Template → Send Auto-Reply Email
- **Condition**: `auto_reply_enabled == true` AND customer email exists
- **Template Processing**: Replace {{name}}, {{service}}, {{business_name}} variables
- **To**: Customer's email address

### Node 17: Success Response
- **Type**: Respond to Webhook
- **Status**: 200
- **Body**: `{"ok": true, "lead_id": "...", "timestamp": "..."}`
- **Purpose**: Confirm successful processing to Cloudflare Worker

## Testing the Workflow

### 1. Test from n8n

1. Open workflow in n8n
2. Click **Test Workflow**
3. Click **Webhook** node → **Listen for Test Event**
4. Send test POST request:

```bash
curl -X POST https://temp.example.com/webhook/lead-intake \
  -H "Content-Type: application/json" \
  -H "X-Lead-Secret: your-secret-key-here" \
  -d '{
    "client_id": "example",
    "name": "Test Customer",
    "phone": "5551234567",
    "email": "test@example.com",
    "message": "I need a quote for deep cleaning",
    "service": "Deep Cleaning",
    "source": "website",
    "utm": "utm_source=google&utm_medium=cpc",
    "ip": "192.0.2.1",
    "user_agent": "Mozilla/5.0",
    "timestamp": "2025-12-28T18:00:00.000Z"
  }'
```

### 2. Verify Results

Check:
- ✅ Lead inserted in database: `SELECT * FROM leads ORDER BY created_at DESC LIMIT 1;`
- ✅ Owner received SMS (check phone)
- ✅ Owner received email (check inbox)
- ✅ Customer received auto-reply SMS (if enabled)
- ✅ Customer received auto-reply email (if enabled)
- ✅ Webhook returned 200 OK with lead_id

### 3. Test from Cloudflare Worker

After deploying the worker and Astro site:

1. Visit your website
2. Fill out contact form
3. Submit
4. Check n8n execution log
5. Verify notifications

## Monitoring & Logs

### View Workflow Executions

1. In n8n: **Executions** tab
2. Filter by workflow: "Lead Intake - Example"
3. Click any execution to see detailed logs

### Common Issues

**Issue**: Webhook returns 401 Unauthorized
- **Fix**: Ensure X-Lead-Secret matches in both Worker and n8n

**Issue**: Database insert fails
- **Fix**: Check PostgreSQL credentials and table exists

**Issue**: SMS not sending
- **Fix**: 
  - Verify Twilio credentials
  - Check phone number format (E.164: +1234567890)
  - Ensure TWILIO_FROM_NUMBER is set

**Issue**: Email not sending
- **Fix**:
  - Verify SMTP credentials
  - Check from/to email addresses
  - Enable "Less secure app access" for Gmail
  - Use App Password for Gmail (not regular password)

**Issue**: Auto-reply not working
- **Fix**: 
  - Check `auto_reply_enabled = true` in clients table
  - Verify template content exists
  - Check customer phone/email is valid

## Customization

### Modify SMS Template

Edit node **Send SMS to Owner**:

```
🔔 New Lead: {{$json.business_name}}

👤 {{$json.name}}
📞 {{$json.phone}}
💬 "{{$json.message_snippet}}"

Reply ASAP for best conversion!
```

### Modify Email HTML

Edit node **Send Email to Owner** → Email Type: HTML

The template supports these variables:
- `{{$json.name}}`
- `{{$json.phone}}`
- `{{$json.email}}`
- `{{$json.message}}`
- `{{$json.service}}`
- `{{$json.source}}`
- `{{$json.utm_source}}`
- `{{$json.ip}}`
- `{{$json.timestamp}}`
- `{{$json.lead_id}}`

### Add Additional Notifications

Example: Send to Slack

1. Add **Slack** node after "Merge Data"
2. Configure webhook URL
3. Format message with lead details
4. Connect to "Success Response"

### Add Lead Assignment

Example: Assign leads to team members

1. Add column to clients table: `assigned_to VARCHAR(255)`
2. Update Lookup Client query to include `assigned_to`
3. Send notification to assigned person instead of/in addition to owner

## Database Queries

### View All Leads

```sql
SELECT l.id, l.client_id, l.name, l.phone, l.email, l.service, l.source, l.created_at
FROM leads l
ORDER BY l.created_at DESC
LIMIT 50;
```

### Leads by Client

```sql
SELECT * FROM leads
WHERE client_id = 'example'
ORDER BY created_at DESC;
```

### Leads by Source

```sql
SELECT source, COUNT(*) as count, DATE(created_at) as date
FROM leads
WHERE client_id = 'example'
GROUP BY source, DATE(created_at)
ORDER BY date DESC, count DESC;
```

### Today's Leads

```sql
SELECT * FROM leads
WHERE created_at >= CURRENT_DATE
ORDER BY created_at DESC;
```

### Update Client Settings

```sql
-- Enable auto-reply
UPDATE clients
SET auto_reply_enabled = true
WHERE client_id = 'example';

-- Update auto-reply SMS
UPDATE clients
SET auto_reply_sms = 'Thank you! We will contact you within 24 hours.'
WHERE client_id = 'example';

-- Disable email notifications
UPDATE clients
SET notify_email = false
WHERE client_id = 'example';
```

### Lead Statistics

```sql
-- Total leads per client
SELECT client_id, COUNT(*) as total_leads
FROM leads
GROUP BY client_id;

-- Conversion funnel (requires status field)
SELECT status, COUNT(*) as count
FROM leads
WHERE client_id = 'example'
GROUP BY status;

-- Leads per day (last 30 days)
SELECT DATE(created_at) as date, COUNT(*) as leads
FROM leads
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY DATE(created_at)
ORDER BY date DESC;
```

## Security Best Practices

1. **Rotate Secrets**: Change LEAD_SECRET periodically
2. **Use Strong Passwords**: For database and SMTP
3. **Enable 2FA**: On Twilio, email provider, Cloudflare
4. **Monitor Logs**: Check for suspicious activity
5. **Rate Limiting**: Configure in Cloudflare Worker if needed
6. **Backup Database**: Regular automated backups
7. **Encrypt Sensitive Data**: Consider encrypting PII in database

## Cost Estimates

**Twilio SMS** (USA):
- $0.0079 per outbound SMS
- ~$0.80 for 100 leads (2 SMS per lead: owner + customer)

**Email** (Postmark/SendGrid):
- Free tiers: 100-10,000 emails/month
- Paid: $0.001 - $0.0001 per email

**Total for 100 leads/month**: ~$1-2

## Troubleshooting Checklist

- [ ] PostgreSQL tables created successfully
- [ ] Seed data inserted (check with SELECT)
- [ ] n8n workflow imported
- [ ] All credentials configured and tested
- [ ] Environment variables set (LEAD_SECRET, TWILIO_FROM_NUMBER, SMTP_FROM_EMAIL)
- [ ] Workflow activated (toggle is ON)
- [ ] Webhook URL copied to Cloudflare Worker
- [ ] Test request returns 200 OK
- [ ] Lead appears in database
- [ ] Owner receives notifications
- [ ] Customer receives auto-reply (if enabled)

## Support Resources

- **n8n Documentation**: https://docs.n8n.io/
- **Twilio Docs**: https://www.twilio.com/docs
- **PostgreSQL Docs**: https://www.postgresql.org/docs/
- **n8n Community**: https://community.n8n.io/

---

🎯 Complete lead management system ready for production!
