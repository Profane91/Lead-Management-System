# Pre-Commit Checklist

Before pushing to GitHub, verify:

## ✅ Sensitive Data Removed

- [ ] No passwords in any files
- [ ] No API keys or secrets in code
- [ ] No personal email addresses
- [ ] No specific domain names (use placeholders)
- [ ] `.env` file is gitignored
- [ ] `.dev.vars` files are gitignored

## ✅ Files Prepared

- [ ] `.env.example` has placeholder values
- [ ] `README.md` is updated with generic examples
- [ ] `SETUP.md` has step-by-step instructions
- [ ] `DEPLOYMENT.md` has architecture and troubleshooting
- [ ] All component READMEs are complete

## ✅ Configuration Files

- [ ] `docker-compose.yml` uses environment variables
- [ ] `wrangler.toml` has placeholder account_id
- [ ] Workflow files have placeholder secrets
- [ ] No hardcoded credentials anywhere

## ✅ Documentation

- [ ] Installation instructions are clear
- [ ] All prerequisites are listed
- [ ] Examples use generic domains
- [ ] Troubleshooting section is complete

## Commands to Run Before Commit

```bash
# 1. Verify .env is not tracked
git status | grep ".env"
# Should only show .env.example

# 2. Search for sensitive data
grep -r "your-actual-password\|your-real-domain\|your-api-key" . --exclude-dir=node_modules --exclude-dir=.git --exclude=.env

# 3. Check what will be committed
git status

# 4. Review changes
git diff

# 5. Add files
git add .

# 6. Commit
git commit -m "Initial commit: Complete lead management system"

# 7. Push
git push origin main
```

## Post-Push Verification

- [ ] Repository is public/private as intended
- [ ] README renders correctly on GitHub
- [ ] No sensitive data visible in any files
- [ ] `.env.example` is visible
- [ ] `.env` is NOT in repository

## If You Find Sensitive Data After Push

```bash
# Remove sensitive file from history
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch path/to/sensitive/file" \
  --prune-empty --tag-name-filter cat -- --all

# Force push (WARNING: Rewrites history)
git push origin --force --all
```

Better: Delete repository and recreate if secrets were exposed.
