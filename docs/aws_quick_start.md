# AWS Secrets - Quick Start (5 Minutes)

If you're comfortable with AWS, here's the TL;DR version.

## What We Built
- Secrets fetched from AWS Systems Manager Parameter Store in production
- Falls back to environment variables in dev/test
- Automatic caching (5 min TTL)
- Zero cost (uses free tier)

## Setup (First Time Only)

### 1. Create IAM User (1 min)
```bash
# Via AWS Console
IAM → Users → Create user
Name: qlarius-prod-app
Attach: AmazonSSMReadOnlyAccess
Create access key → Save credentials
```

### 2. Create Parameters (2 min)
```bash
# Via AWS CLI (faster) or Console
aws ssm put-parameter \
  --name /qlarius/twilio/account-sid \
  --value "AC..." \
  --type SecureString

aws ssm put-parameter \
  --name /qlarius/twilio/auth-token \
  --value "your-token" \
  --type SecureString

aws ssm put-parameter \
  --name /qlarius/twilio/verify-service-sid \
  --value "VA..." \
  --type SecureString

# Generate NEW encryption key for production
KEY=$(elixir -e ":crypto.strong_rand_bytes(32) |> Base.encode64() |> IO.puts()")

aws ssm put-parameter \
  --name /qlarius/cloak-key \
  --value "$KEY" \
  --type SecureString
```

### 3. Grant KMS Decrypt Permission (1 min)
```bash
# Via Console
KMS → AWS managed keys → aws/ssm
Key users → Add → Select qlarius-prod-app → Add
```

### 4. Configure Production Server (1 min)
```bash
# Set these three environment variables:
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION="us-east-1"

# Remove these (no longer needed):
unset TWILIO_ACCOUNT_SID
unset TWILIO_AUTH_TOKEN
unset TWILIO_VERIFY_SERVICE_SID
unset CLOAK_KEY
```

## How It Works

**Development/Test:**
```elixir
# Uses environment variables
System.get_env("TWILIO_ACCOUNT_SID")
```

**Production:**
```elixir
# Fetches from AWS Parameter Store
Qlarius.Secrets.fetch_twilio_config()
# Returns: %{account_sid: "AC...", auth_token: "...", verify_service_sid: "VA..."}
```

## File Changes

**New files:**
- `lib/qlarius/secrets.ex` - Fetches secrets from AWS or env vars
- `docs/aws_secrets_setup_guide.md` - Detailed walkthrough

**Modified:**
- `mix.exs` - Added `ex_aws_ssm`
- `config/runtime.exs` - Uses `Qlarius.Secrets` in production
- `lib/qlarius/application.ex` - Initializes secrets cache

## Testing Locally

```bash
# Test AWS integration locally
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION="us-east-1"

MIX_ENV=prod iex -S mix

# Check if secrets load
iex> Qlarius.Secrets.fetch_twilio_config()
# Should return your Twilio credentials
```

## Deployment Platforms

### Fly.io
```bash
fly secrets set AWS_ACCESS_KEY_ID="AKIA..."
fly secrets set AWS_SECRET_ACCESS_KEY="..."
fly secrets set AWS_DEFAULT_REGION="us-east-1"
```

### Render
```
Environment → Add:
- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY  
- AWS_DEFAULT_REGION
```

### Heroku
```bash
heroku config:set AWS_ACCESS_KEY_ID="AKIA..."
heroku config:set AWS_SECRET_ACCESS_KEY="..."
heroku config:set AWS_DEFAULT_REGION="us-east-1"
```

### AWS EC2/ECS (Recommended)
Use IAM Instance Roles instead:
1. Create role with SSM permissions
2. Attach to instance
3. No credentials needed!

## Updating Secrets (No Redeploy!)

```bash
# Update via CLI
aws ssm put-parameter \
  --name /qlarius/twilio/auth-token \
  --value "new-token" \
  --type SecureString \
  --overwrite

# Or via Console
Systems Manager → Parameter Store → Click parameter → Edit → Save

# App picks up new value within 5 minutes (cache TTL)
# Or restart for immediate effect
```

## Cost: $0.00/month
- Parameter Store Standard: Free (10k requests/month)
- KMS encryption: Free (20k requests/month)
- IAM: Free

## Troubleshooting

**"Failed to fetch from AWS"**
```bash
# Test AWS access
aws ssm get-parameter --name /qlarius/twilio/account-sid --with-decryption

# Check IAM permissions
aws iam list-attached-user-policies --user-name qlarius-prod-app

# Check KMS permission
aws kms describe-key --key-id alias/aws/ssm
```

**"Access Denied"**
- Did you add IAM user to KMS key users?
- Is the parameter type "SecureString"?

**Works locally, fails in prod**
- Check `MIX_ENV=prod` is set
- Check `AWS_DEFAULT_REGION` is set
- Check network access to AWS endpoints

## Security Notes

✅ **DO:**
- Rotate access keys every 90 days
- Use IAM roles on EC2/ECS (no keys needed)
- Enable CloudTrail for audit logs

❌ **DON'T:**
- Commit AWS keys to git
- Share IAM credentials
- Use root account credentials

## Need More Details?
See `docs/aws_secrets_setup_guide.md` for the full step-by-step guide with screenshots and troubleshooting.

## Parameter Names Reference
```
/qlarius/cloak-key                       # Database encryption key
/qlarius/twilio/account-sid              # Twilio Account SID
/qlarius/twilio/auth-token               # Twilio Auth Token
/qlarius/twilio/verify-service-sid       # Twilio Verify Service SID
```

## AWS Console Quick Links
- **Parameter Store:** https://console.aws.amazon.com/systems-manager/parameters
- **IAM Users:** https://console.aws.amazon.com/iam/home#/users
- **KMS Keys:** https://console.aws.amazon.com/kms/home#/kms/keys

