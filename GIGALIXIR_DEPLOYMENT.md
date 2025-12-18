# Gigalixir Deployment Guide for Qlarius

## Overview

Qlarius is configured to automatically use **environment variables** on Gigalixir (and other PaaS platforms). The app detects Gigalixir by checking for the `GIGALIXIR_APP_NAME` environment variable and uses env vars instead of AWS Parameter Store.

---

## Step 1: Generate Encryption Key

First, generate a secure encryption key for the database:

```bash
# Generate base64-encoded encryption key (32 bytes)
openssl rand -base64 32
```

**Save this key securely!** You'll need it for the next step.

---

## Step 2: Set Environment Variables

Set all required environment variables in Gigalixir:

```bash
# Database (usually auto-configured by Gigalixir when you provision a database)
# gigalixir pg:create --free
# DATABASE_URL is set automatically

# Phoenix secret key base (generate with: mix phx.gen.secret)
gigalixir config:set SECRET_KEY_BASE="your-secret-key-base-here"

# Encryption key (from Step 1)
gigalixir config:set CLOAK_KEY="your-base64-key-from-step-1"

# Twilio credentials (from https://console.twilio.com)
gigalixir config:set TWILIO_ACCOUNT_SID="ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
gigalixir config:set TWILIO_AUTH_TOKEN="your-twilio-auth-token"
gigalixir config:set TWILIO_VERIFY_SERVICE_SID="VAxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# App hostname
gigalixir config:set PHX_HOST="your-app.gigalixirapp.com"

# Optional: Disable carrier validation in development/testing
# gigalixir config:set SKIP_CARRIER_VALIDATION="true"
```

### Get Your Twilio Credentials

1. Go to [Twilio Console](https://console.twilio.com)
2. **Account SID** and **Auth Token** are on the main dashboard
3. For **Verify Service SID**:
   - Go to Explore Products → Verify → Services
   - Create a service if you haven't
   - Copy the Service SID (starts with `VA`)

---

## Step 3: Verify Environment Variables

Check that all variables are set:

```bash
gigalixir config
```

You should see:
- `SECRET_KEY_BASE`
- `CLOAK_KEY`
- `TWILIO_ACCOUNT_SID`
- `TWILIO_AUTH_TOKEN`
- `TWILIO_VERIFY_SERVICE_SID`
- `PHX_HOST`
- `DATABASE_URL` (auto-set if you provisioned a database)

---

## Step 4: Run Database Migrations

If this is your first deployment or you have new migrations:

```bash
# Run migrations
gigalixir run mix ecto.migrate

# Seed alias words (if not done yet)
gigalixir run mix run priv/repo/seeds_alias_words.exs
```

---

## Step 5: Deploy

```bash
# Commit your changes
git add -A
git commit -m "Fix production boot issue and configure for Gigalixir"

# Push to Gigalixir (this triggers deployment)
git push gigalixir main
```

If your main branch is named `master`:
```bash
git push gigalixir master
```

---

## Step 6: Monitor Deployment

Watch the logs during deployment:

```bash
gigalixir logs
```

**Look for these success messages:**
- ✅ `"Fetching Twilio credentials from environment variables"`
- ✅ `"Secrets cache initialized"`
- ✅ No errors about missing CLOAK_KEY or Twilio config

---

## Step 7: Test the App

### 7.1 Check Health

```bash
# Open your app in browser
gigalixir open

# Or visit directly
open https://your-app.gigalixirapp.com
```

### 7.2 Test Authentication

1. Navigate to `/register`
2. Enter a US mobile number
3. Click "Send Code"
4. Check that you receive an SMS with a verification code
5. Enter the code and verify it works

### 7.3 Check Logs

```bash
# Watch live logs
gigalixir logs -f

# Check for errors
gigalixir logs | grep -i error

# Check Twilio calls
gigalixir logs | grep -i twilio
```

---

## Troubleshooting

### Issue: "CLOAK_KEY environment variable not set"

**Solution:**
```bash
# Generate and set the key
gigalixir config:set CLOAK_KEY="$(openssl rand -base64 32)"

# Restart the app
gigalixir ps:restart
```

### Issue: "Failed to fetch Twilio credentials"

**Check environment variables:**
```bash
gigalixir config | grep TWILIO
```

**Verify Twilio credentials are correct:**
- Login to [Twilio Console](https://console.twilio.com)
- Verify Account SID matches
- Generate a new Auth Token if needed
- Check Verify Service SID is correct

**Update if needed:**
```bash
gigalixir config:set TWILIO_ACCOUNT_SID="ACxxxx"
gigalixir config:set TWILIO_AUTH_TOKEN="your-token"
gigalixir config:set TWILIO_VERIFY_SERVICE_SID="VAxxxx"
gigalixir ps:restart
```

### Issue: App crashes with "ETS table does not exist"

This should be fixed with the recent code changes. If you still see it:

```bash
# Check you have the latest code
git pull origin main
git push gigalixir main

# Force rebuild
gigalixir ps:restart
```

### Issue: Database not connected

**Provision a database if you haven't:**
```bash
# Free tier (limited)
gigalixir pg:create --free

# Paid tier (recommended for production)
gigalixir pg:create --size 0.6
```

**Run migrations:**
```bash
gigalixir run mix ecto.migrate
```

### Issue: Can't send SMS to phone numbers

**Check Twilio account status:**
1. Trial accounts can only send to verified numbers
2. Verify your Twilio account to send to any number
3. Check Twilio balance in the console

**Enable carrier validation:**
- Line Type Intelligence must be enabled in Twilio console
- Or disable validation: `gigalixir config:set SKIP_CARRIER_VALIDATION="true"`

---

## Useful Gigalixir Commands

```bash
# View logs
gigalixir logs
gigalixir logs -f  # Follow live

# Check app status
gigalixir ps

# Restart app
gigalixir ps:restart

# Scale app (if needed)
gigalixir ps:scale --replicas=2

# Run remote console
gigalixir ps:remote_console

# Run mix commands
gigalixir run mix ecto.migrate
gigalixir run mix run priv/repo/seeds_alias_words.exs

# View config
gigalixir config

# Set config
gigalixir config:set KEY=value

# Database operations
gigalixir pg
gigalixir pg:psql  # Connect to database
```

---

## Remote Console Testing

Connect to the production app to test secrets:

```bash
# Start remote console
gigalixir ps:remote_console
```

In the console:
```elixir
# Test Twilio config
Qlarius.Services.Twilio.account_sid()
# Should return: "ACxxxxxxxxxxxxxx..."

# Test encryption is configured
Qlarius.Vault.__config__() |> get_in([:ciphers, :default])
# Should show cipher configuration

# Test sending SMS (optional - costs money!)
Qlarius.Services.Twilio.send_verification("+15551234567")

# Test alias generation
Qlarius.Accounts.AliasGenerator.generate_base_names()
# Should return 5 adjective-noun combinations

# Exit console
Ctrl+C, Ctrl+C
```

---

## Environment Variables Reference

### Required

| Variable | Description | Example |
|----------|-------------|---------|
| `SECRET_KEY_BASE` | Phoenix secret | Generated by `mix phx.gen.secret` |
| `PHX_HOST` | App hostname | `your-app.gigalixirapp.com` |
| `DATABASE_URL` | Postgres URL | Auto-set by Gigalixir |
| `CLOAK_KEY` | Encryption key | Base64 string from `openssl rand -base64 32` |
| `TWILIO_ACCOUNT_SID` | Twilio Account SID | `ACxxxxxxxxxxxxxxxx...` |
| `TWILIO_AUTH_TOKEN` | Twilio Auth Token | From Twilio Console |
| `TWILIO_VERIFY_SERVICE_SID` | Verify Service SID | `VAxxxxxxxxxxxxxxxx...` |

### Optional

| Variable | Description | Default |
|----------|-------------|---------|
| `SKIP_CARRIER_VALIDATION` | Skip carrier checks | `false` |
| `POOL_SIZE` | Database pool size | `10` |
| `PORT` | HTTP port | `4000` (set by Gigalixir) |

---

## Cost Optimization

### Free Tier Limitations

Gigalixir free tier includes:
- 1 instance (sleeps after 30min inactivity)
- Limited database (10k rows)
- No custom domains

**For production, upgrade to paid tier:**
```bash
gigalixir account:upgrade
gigalixir ps:scale --size=0.5  # Adjust as needed
```

### Twilio Costs

- **Verify API**: ~$0.05 per verification
- **Free trial**: $15 credit (enough for ~300 verifications)
- **Carrier lookup**: Included with Line Type Intelligence add-on

**Estimate monthly costs:**
- 1000 registrations/month = ~$50
- 10,000 registrations/month = ~$500

---

## Rollback Plan

If deployment fails:

```bash
# Check recent releases
gigalixir releases

# Rollback to previous version
gigalixir releases:rollback

# Or specific version
gigalixir releases:rollback v123
```

---

## Security Best Practices

1. **Never commit secrets** - Use `gigalixir config:set`
2. **Rotate keys periodically** - Update TWILIO_AUTH_TOKEN every 90 days
3. **Use HTTPS only** - Gigalixir provides SSL automatically
4. **Monitor logs** - Set up alerts for errors
5. **Backup CLOAK_KEY** - Losing it means data loss

---

## Monitoring & Alerts

### Set up log alerts

Gigalixir doesn't have built-in alerting on free tier. Consider:
- [Sentry](https://sentry.io) for error tracking
- [Papertrail](https://papertrailapp.com) for log aggregation
- [AppSignal](https://appsignal.com) for Elixir-specific monitoring

### Add Sentry (optional)

```bash
# Add to mix.exs
{:sentry, "~> 10.0"},

# Configure in runtime.exs
config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: :prod

# Set in Gigalixir
gigalixir config:set SENTRY_DSN="https://xxx@sentry.io/xxx"
```

---

## Support

- **Gigalixir Docs**: https://gigalixir.readthedocs.io/
- **Gigalixir Support**: support@gigalixir.com
- **Twilio Docs**: https://www.twilio.com/docs/verify

---

## Quick Deployment Checklist

- [ ] Set `CLOAK_KEY` (generate with `openssl rand -base64 32`)
- [ ] Set `SECRET_KEY_BASE` (generate with `mix phx.gen.secret`)
- [ ] Set all Twilio environment variables
- [ ] Set `PHX_HOST` to your Gigalixir domain
- [ ] Provision database (`gigalixir pg:create`)
- [ ] Run migrations (`gigalixir run mix ecto.migrate`)
- [ ] Seed alias words (`gigalixir run mix run priv/repo/seeds_alias_words.exs`)
- [ ] Deploy (`git push gigalixir main`)
- [ ] Test registration flow with SMS verification
- [ ] Monitor logs for errors

---

## Summary

Gigalixir deployment is straightforward:

1. **Set environment variables** → Secrets configured
2. **git push gigalixir** → Automatic build & deploy
3. **gigalixir logs** → Monitor success
4. **Test authentication** → Verify SMS works

The app automatically detects Gigalixir and uses environment variables instead of AWS Parameter Store. No Docker, Kubernetes, or AWS configuration needed! 🚀

