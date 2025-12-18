# AWS Secrets Setup Guide - Step by Step

This guide will walk you through setting up AWS Systems Manager Parameter Store for securely storing your Qlarius production secrets (Twilio credentials and encryption keys).

## Why This Matters
- ✅ Secrets encrypted at rest with AWS KMS
- ✅ Free for standard parameters (no monthly cost)
- ✅ Audit trail of who accessed secrets
- ✅ Can update secrets without redeploying
- ✅ IAM-based access control

## Prerequisites
- AWS Account (free tier is fine)
- AWS CLI installed (optional but helpful)
- Your Twilio credentials ready

---

## Part 1: AWS Account Setup (if you don't have one)

### 1. Create AWS Account
1. Go to https://aws.amazon.com
2. Click "Create an AWS Account" (top right)
3. Enter email address and account name
4. Follow the verification steps
5. Add payment method (required but Parameter Store is free)
6. Choose "Basic Support - Free" plan

**⏱️ This takes about 10 minutes**

---

## Part 2: Set Up IAM User for Your Application

AWS best practice: Don't use root account credentials. Create an IAM user.

### 1. Navigate to IAM
1. Log into AWS Console (https://console.aws.amazon.com)
2. In the search bar at the top, type "IAM"
3. Click "IAM" in the results

### 2. Create IAM User
1. Click "Users" in the left sidebar
2. Click "Create user" (orange button, top right)
3. **User name:** `qlarius-prod-app`
4. **DO NOT** check "Provide user access to AWS Management Console"
5. Click "Next"

### 3. Set Permissions
1. Select "Attach policies directly"
2. In the search box, type: `AmazonSSMReadOnlyAccess`
3. Check the box next to "AmazonSSMReadOnlyAccess"
4. Click "Next"
5. Click "Create user"

### 4. Create Access Keys
1. Click on the user you just created (`qlarius-prod-app`)
2. Click "Security credentials" tab
3. Scroll down to "Access keys"
4. Click "Create access key"
5. Select "Application running outside AWS"
6. Click "Next"
7. (Optional) Add description: "Qlarius production server"
8. Click "Create access key"

### 5. Save Your Access Keys ⚠️ IMPORTANT
You'll see two values:
- **Access key ID** (starts with AKIA...)
- **Secret access key** (long random string)

**Copy these immediately** - you can't see the secret again!

Save them somewhere secure (password manager):
```
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
```

---

## Part 3: Store Secrets in Parameter Store

### 1. Navigate to Systems Manager
1. In the AWS Console search bar, type "Systems Manager"
2. Click "Systems Manager" in the results
3. In the left sidebar, scroll down to "Application Management"
4. Click "Parameter Store"

### 2. Create Twilio Account SID Parameter
1. Click "Create parameter" (orange button)
2. Fill in:
   - **Name:** `/qlarius/twilio/account-sid`
   - **Description:** "Twilio Account SID for SMS verification"
   - **Tier:** Standard (free)
   - **Type:** SecureString ⚠️ IMPORTANT
   - **KMS key source:** "My current account"
   - **KMS Key ID:** alias/aws/ssm (default, this is fine)
   - **Value:** Paste your Twilio Account SID (starts with AC...)
3. Click "Create parameter"

### 3. Create Twilio Auth Token Parameter
1. Click "Create parameter" again
2. Fill in:
   - **Name:** `/qlarius/twilio/auth-token`
   - **Description:** "Twilio Auth Token"
   - **Tier:** Standard
   - **Type:** SecureString ⚠️ IMPORTANT
   - **KMS key source:** "My current account"
   - **KMS Key ID:** alias/aws/ssm
   - **Value:** Paste your Twilio Auth Token
3. Click "Create parameter"

### 4. Create Twilio Verify Service SID Parameter
1. Click "Create parameter" again
2. Fill in:
   - **Name:** `/qlarius/twilio/verify-service-sid`
   - **Description:** "Twilio Verify Service SID"
   - **Tier:** Standard
   - **Type:** SecureString ⚠️ IMPORTANT
   - **KMS key source:** "My current account"
   - **KMS Key ID:** alias/aws/ssm
   - **Value:** Paste your Twilio Verify Service SID (starts with VA...)
3. Click "Create parameter"

### 5. Create Cloak Encryption Key Parameter
1. First, generate a NEW encryption key for production:
   ```bash
   elixir -e ":crypto.strong_rand_bytes(32) |> Base.encode64() |> IO.puts()"
   ```
   Copy the output (it will look like: `Ab3dF...==`)

2. Click "Create parameter" again
3. Fill in:
   - **Name:** `/qlarius/cloak-key`
   - **Description:** "Cloak encryption key for database field encryption"
   - **Tier:** Standard
   - **Type:** SecureString ⚠️ IMPORTANT
   - **KMS key source:** "My current account"
   - **KMS Key ID:** alias/aws/ssm
   - **Value:** Paste your generated encryption key
4. Click "Create parameter"

### 6. Verify All Parameters Created
You should now see 4 parameters in Parameter Store:
- `/qlarius/cloak-key`
- `/qlarius/twilio/account-sid`
- `/qlarius/twilio/auth-token`
- `/qlarius/twilio/verify-service-sid`

All should show:
- Type: SecureString
- Tier: Standard
- KMS Key ID: alias/aws/ssm

---

## Part 4: Grant IAM User Permission to Decrypt

The IAM user can READ the parameters, but we need to allow DECRYPTION.

### 1. Navigate to KMS
1. In AWS Console search bar, type "KMS"
2. Click "Key Management Service"
3. Click "AWS managed keys" in the left sidebar
4. Click on the key named "aws/ssm"

### 2. Add IAM User to Key Policy
1. Scroll down to "Key users"
2. Click "Add" button
3. Search for `qlarius-prod-app`
4. Check the box next to your IAM user
5. Click "Add"

---

## Part 5: Configure Your Production Server

### On Your Production Server (e.g., EC2, Fly.io, Render, etc.):

1. **Set AWS credentials as environment variables:**
   ```bash
   export AWS_ACCESS_KEY_ID="AKIA..."
   export AWS_SECRET_ACCESS_KEY="..."
   export AWS_DEFAULT_REGION="us-east-1"  # or your region
   ```

2. **Deploy your Qlarius application**
   - The app will automatically fetch secrets from Parameter Store in production
   - No need to set TWILIO_* or CLOAK_KEY env vars anymore!

### For Different Deployment Platforms:

#### **Fly.io:**
```bash
fly secrets set AWS_ACCESS_KEY_ID="AKIA..."
fly secrets set AWS_SECRET_ACCESS_KEY="..."
fly secrets set AWS_DEFAULT_REGION="us-east-1"
```

#### **Render:**
1. Go to your service dashboard
2. Click "Environment"
3. Add three environment variables:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_DEFAULT_REGION`

#### **Heroku:**
```bash
heroku config:set AWS_ACCESS_KEY_ID="AKIA..."
heroku config:set AWS_SECRET_ACCESS_KEY="..."
heroku config:set AWS_DEFAULT_REGION="us-east-1"
```

#### **AWS EC2/ECS (Recommended):**
Use IAM Roles instead of access keys (even more secure):
1. Create an IAM role with SSM permissions
2. Attach role to your EC2 instance
3. No need to set AWS credentials at all!

---

## Part 6: Testing

### Test Locally (Optional)
You can test the AWS integration locally:

```bash
# Set AWS credentials
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION="us-east-1"

# Run in production mode
MIX_ENV=prod mix phx.server
```

You should see in the logs:
```
[info] Fetching Twilio credentials from AWS Parameter Store
```

### Test Parameter Fetch (AWS CLI)
If you have AWS CLI installed:

```bash
# Configure AWS CLI
aws configure
# Enter your access key, secret key, region

# Test fetching a parameter
aws ssm get-parameter --name /qlarius/twilio/account-sid --with-decryption

# Should return JSON with your Twilio Account SID
```

---

## Security Best Practices

### ✅ DO:
- Use different AWS accounts for staging and production
- Rotate IAM access keys every 90 days
- Enable AWS CloudTrail to log all Parameter Store access
- Use IAM roles instead of access keys when possible (EC2, ECS, Lambda)
- Set up AWS billing alerts

### ❌ DON'T:
- Commit AWS access keys to git
- Share IAM credentials between team members
- Use root account credentials
- Store secrets in code or config files

---

## Updating Secrets (No Redeployment Needed!)

### To Update a Secret:
1. Go to Systems Manager > Parameter Store
2. Click on the parameter you want to update
3. Click "Edit"
4. Change the value
5. Click "Save changes"

Your app will use the new value within 5 minutes (cache TTL).

To force immediate update, restart your app:
```bash
# Fly.io
fly apps restart qlarius

# Render
Click "Manual Deploy" > "Deploy latest commit"

# Heroku
heroku restart
```

---

## Troubleshooting

### Error: "Failed to fetch Twilio config from AWS"

**Check:**
1. Are AWS credentials set correctly?
   ```bash
   echo $AWS_ACCESS_KEY_ID
   echo $AWS_SECRET_ACCESS_KEY
   echo $AWS_DEFAULT_REGION
   ```

2. Can you access AWS from your server?
   ```bash
   aws ssm get-parameter --name /qlarius/twilio/account-sid --with-decryption
   ```

3. Does the IAM user have the right permissions?
   - AmazonSSMReadOnlyAccess policy attached?
   - Added as key user in KMS?

### Error: "Parameter not found"

**Check:**
- Parameter names are case-sensitive
- Names must start with `/`
- Did you create all 4 parameters?

### Error: "Access denied" or "KMS decrypt error"

**Check:**
- Did you add the IAM user to KMS key users? (Part 4, Step 2)
- Is the parameter type set to "SecureString"?

### App works locally but not in production

**Check:**
- `MIX_ENV=prod` is set in production
- AWS region is set correctly (`AWS_DEFAULT_REGION`)
- Network access: Can your server reach AWS endpoints?

---

## Cost Breakdown

### What You're Using (All FREE):
- **Parameter Store Standard parameters:** Free (up to 10,000 API requests/month)
- **KMS encryption/decryption:** First 20,000 requests/month free
- **IAM users and policies:** Free

### You only pay if you exceed:
- 10,000 Parameter Store API requests/month (~7 requests/minute continuously)
- 20,000 KMS requests/month

**Typical Qlarius usage:** ~1,000 requests/month = **$0.00**

---

## Next Steps After Setup

1. **Remove old environment variables** from your production server:
   - You can delete TWILIO_* env vars
   - You can delete CLOAK_KEY env var
   - Keep AWS_* env vars

2. **Set up AWS CloudTrail** (optional but recommended):
   - Logs all Parameter Store access
   - Helps with security audits and compliance

3. **Set up billing alerts:**
   - Go to AWS Billing console
   - Create alert for charges over $10

4. **Document for your team:**
   - Who has AWS console access
   - How to rotate secrets
   - Emergency contact if AWS access is lost

---

## Quick Reference

### Parameter Names:
```
/qlarius/twilio/account-sid
/qlarius/twilio/auth-token
/qlarius/twilio/verify-service-sid
/qlarius/cloak-key
```

### Required Environment Variables (Production):
```bash
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
AWS_DEFAULT_REGION=us-east-1
MIX_ENV=prod
```

### AWS Console Quick Links:
- Parameter Store: https://console.aws.amazon.com/systems-manager/parameters
- IAM Users: https://console.aws.amazon.com/iam/home#/users
- KMS Keys: https://console.aws.amazon.com/kms/home#/kms/keys

---

## Need Help?

**Common AWS regions:**
- US East (N. Virginia): `us-east-1` (cheapest, most services)
- US West (Oregon): `us-west-2`
- EU (Ireland): `eu-west-1`

**Support:**
- AWS Support (Basic plan is free, email only)
- AWS Community Forums: https://forums.aws.amazon.com

---

## Summary Checklist

- [ ] Created AWS account
- [ ] Created IAM user (`qlarius-prod-app`)
- [ ] Attached `AmazonSSMReadOnlyAccess` policy
- [ ] Created and saved access keys
- [ ] Created 4 parameters in Parameter Store (all SecureString)
- [ ] Added IAM user to KMS key users
- [ ] Set AWS_* environment variables on production server
- [ ] Tested deployment
- [ ] Removed old TWILIO_* environment variables
- [ ] Set up billing alert
- [ ] Documented credentials in secure location

**You're done!** Your secrets are now securely managed in AWS. 🎉

