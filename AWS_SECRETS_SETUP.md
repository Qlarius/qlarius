# AWS Secrets Manager Setup for Qlarius Production

## Overview

Qlarius uses AWS Systems Manager Parameter Store to securely manage production secrets (Twilio credentials and encryption keys). This guide walks you through the complete setup process.

## Prerequisites

- AWS account with admin access
- AWS CLI installed and configured
- IAM permissions to create parameters and policies
- Production Kubernetes cluster with IAM role for service account (IRSA)

---

## Step 1: Create AWS IAM Policy

Create an IAM policy that grants read access to your Parameter Store secrets.

```bash
# Create the policy JSON file
cat > qlarius-secrets-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ],
      "Resource": [
        "arn:aws:ssm:*:*:parameter/qlarius/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": [
            "ssm.us-east-1.amazonaws.com"
          ]
        }
      }
    }
  ]
}
EOF

# Create the IAM policy
aws iam create-policy \
  --policy-name QlariusSecretsReadPolicy \
  --policy-document file://qlarius-secrets-policy.json
```

**Note the Policy ARN** from the output - you'll need it for Step 3.

---

## Step 2: Store Secrets in Parameter Store

### 2.1 Generate Encryption Key

```bash
# Generate a secure base64-encoded encryption key (32 bytes)
CLOAK_KEY=$(openssl rand -base64 32)
echo "Generated CLOAK_KEY: $CLOAK_KEY"
```

**IMPORTANT**: Save this key securely. If you lose it, you won't be able to decrypt existing data.

### 2.2 Store Parameters in AWS

```bash
# Set your AWS region
export AWS_REGION=us-east-1

# Store Cloak encryption key (SecureString)
aws ssm put-parameter \
  --name "/qlarius/cloak-key" \
  --value "$CLOAK_KEY" \
  --type "SecureString" \
  --description "Encryption key for Qlarius database fields" \
  --region $AWS_REGION

# Store Twilio Account SID
aws ssm put-parameter \
  --name "/qlarius/twilio/account-sid" \
  --value "YOUR_TWILIO_ACCOUNT_SID" \
  --type "SecureString" \
  --description "Twilio Account SID" \
  --region $AWS_REGION

# Store Twilio Auth Token
aws ssm put-parameter \
  --name "/qlarius/twilio/auth-token" \
  --value "YOUR_TWILIO_AUTH_TOKEN" \
  --type "SecureString" \
  --description "Twilio Auth Token" \
  --region $AWS_REGION

# Store Twilio Verify Service SID
aws ssm put-parameter \
  --name "/qlarius/twilio/verify-service-sid" \
  --value "YOUR_VERIFY_SERVICE_SID" \
  --type "SecureString" \
  --description "Twilio Verify Service SID" \
  --region $AWS_REGION
```

### 2.3 Verify Parameters

```bash
# List all Qlarius parameters
aws ssm get-parameters-by-path \
  --path "/qlarius" \
  --recursive \
  --region $AWS_REGION

# Test fetching a parameter (with decryption)
aws ssm get-parameter \
  --name "/qlarius/cloak-key" \
  --with-decryption \
  --region $AWS_REGION
```

---

## Step 3: Configure Kubernetes Service Account (IRSA)

### 3.1 Create IAM Role for Service Account

```bash
# Set your cluster and account details
export CLUSTER_NAME=your-cluster-name
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/QlariusSecretsReadPolicy"

# Create trust policy for IRSA
cat > trust-policy.json << EOF
{
  "Version": "2012-17-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/oidc.eks.${AWS_REGION}.amazonaws.com/id/YOUR_OIDC_ID"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.${AWS_REGION}.amazonaws.com/id/YOUR_OIDC_ID:sub": "system:serviceaccount:default:qlarius-sa"
        }
      }
    }
  ]
}
EOF

# Create the IAM role
aws iam create-role \
  --role-name QlariusSecretsRole \
  --assume-role-policy-document file://trust-policy.json

# Attach the policy to the role
aws iam attach-role-policy \
  --role-name QlariusSecretsRole \
  --policy-arn $POLICY_ARN
```

**Get your OIDC ID**:
```bash
aws eks describe-cluster \
  --name $CLUSTER_NAME \
  --query "cluster.identity.oidc.issuer" \
  --output text | sed 's|https://||'
```

### 3.2 Update Kubernetes Service Account

Add the IAM role annotation to your service account:

```yaml
# kubernetes/service-account.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: qlarius-sa
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::YOUR_ACCOUNT_ID:role/QlariusSecretsRole
```

Apply:
```bash
kubectl apply -f kubernetes/service-account.yaml
```

### 3.3 Update Deployment

Ensure your deployment uses the service account:

```yaml
# kubernetes/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: qlarius
spec:
  template:
    spec:
      serviceAccountName: qlarius-sa
      containers:
      - name: web
        image: your-image
        env:
        - name: AWS_REGION
          value: "us-east-1"
        # No need to set AWS credentials - IRSA handles this
```

---

## Step 4: Configure Application Environment

### 4.1 Required Environment Variables

Your production environment needs:

```bash
# In your deployment/container
export AWS_REGION=us-east-1
export PHX_HOST=your-domain.com
export SECRET_KEY_BASE=your-secret-key-base
export DATABASE_URL=your-database-url

# These are automatically fetched from Parameter Store at boot:
# - TWILIO_ACCOUNT_SID (from /qlarius/twilio/account-sid)
# - TWILIO_AUTH_TOKEN (from /qlarius/twilio/auth-token)
# - TWILIO_VERIFY_SERVICE_SID (from /qlarius/twilio/verify-service-sid)
# - CLOAK_KEY (from /qlarius/cloak-key)
```

### 4.2 How It Works

When your app starts:

1. `config/runtime.exs` runs **before** the application starts
2. It calls `Qlarius.Secrets.fetch_twilio_config_no_cache()` and `fetch_cloak_key_no_cache()`
3. These functions detect `Mix.env() == :prod` and fetch from AWS SSM
4. The fetched values configure Twilio and Cloak
5. After the app starts, the `Qlarius.Secrets` GenServer provides cached access

---

## Step 5: Test the Setup

### 5.1 Local Testing (with AWS credentials)

```bash
# Set AWS credentials locally
export AWS_ACCESS_KEY_ID=your-key
export AWS_SECRET_ACCESS_KEY=your-secret
export AWS_REGION=us-east-1

# Test fetching secrets
mix run -e "IO.inspect(Qlarius.Secrets.fetch_twilio_config_no_cache())"
mix run -e "IO.inspect(Qlarius.Secrets.fetch_cloak_key_no_cache())"
```

### 5.2 Production Deployment

Deploy your app and check logs:

```bash
# Watch pod logs
kubectl logs -f deployment/qlarius

# Look for:
# "Fetching Twilio credentials from AWS Parameter Store"
# "Secrets cache initialized"
```

### 5.3 Verify Secrets Are Working

```bash
# Shell into the pod
kubectl exec -it deployment/qlarius -- /app/bin/qlarius remote

# In the Elixir console:
iex> Qlarius.Services.Twilio.account_sid()
"ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

iex> Qlarius.Vault.__config__() |> get_in([:ciphers, :default]) |> elem(1)
# Should show your cipher config with the key
```

---

## Troubleshooting

### Error: "Failed to fetch Twilio credentials from AWS Parameter Store"

**Possible causes:**

1. **IAM permissions issue** - Verify role has `ssm:GetParameter` permission
2. **Parameter doesn't exist** - Check parameter names match exactly
3. **Wrong region** - Ensure `AWS_REGION` is set correctly
4. **IRSA not configured** - Service account annotation missing

**Debug steps:**

```bash
# Check if IRSA is working
kubectl exec -it deployment/qlarius -- env | grep AWS

# Should show:
# AWS_ROLE_ARN=arn:aws:iam::xxx:role/QlariusSecretsRole
# AWS_WEB_IDENTITY_TOKEN_FILE=/var/run/secrets/eks.amazonaws.com/serviceaccount/token

# Test AWS access from pod
kubectl exec -it deployment/qlarius -- aws ssm get-parameter \
  --name "/qlarius/cloak-key" \
  --with-decryption \
  --region us-east-1
```

### Error: "ETS table does not exist"

This was the original issue. If you still see this:

1. Ensure you're using `fetch_*_no_cache()` functions in `runtime.exs`
2. Verify `Qlarius.Secrets` is in the supervision tree in `application.ex`
3. Check app startup logs for "Secrets cache initialized"

### Error: "CLOAK_KEY not found"

```bash
# Verify parameter exists
aws ssm get-parameter --name "/qlarius/cloak-key" --region us-east-1

# If missing, create it:
aws ssm put-parameter \
  --name "/qlarius/cloak-key" \
  --value "$(openssl rand -base64 32)" \
  --type "SecureString" \
  --region us-east-1
```

### Error: "Twilio verification failed"

```bash
# Check Twilio credentials in Parameter Store
aws ssm get-parameter --name "/qlarius/twilio/account-sid" --with-decryption --region us-east-1
aws ssm get-parameter --name "/qlarius/twilio/auth-token" --with-decryption --region us-east-1
aws ssm get-parameter --name "/qlarius/twilio/verify-service-sid" --with-decryption --region us-east-1

# Verify values match your Twilio console
```

---

## Security Best Practices

1. **Never commit secrets to git** - Use Parameter Store exclusively
2. **Use SecureString type** - Encrypts parameters with AWS KMS
3. **Rotate secrets regularly** - Update parameters and redeploy
4. **Limit IAM permissions** - Only grant `ssm:GetParameter` on `/qlarius/*`
5. **Use separate parameters per environment** - e.g., `/qlarius/staging/*`, `/qlarius/prod/*`
6. **Monitor access** - Enable CloudTrail logging for parameter access
7. **Backup your CLOAK_KEY** - Store securely offline; losing it means data loss

---

## Cost Estimation

AWS Systems Manager Parameter Store pricing (as of 2024):

- **Standard parameters**: Free (up to 10,000 parameters)
- **SecureString (KMS encryption)**: Free for default AWS managed key
- **API calls**: First 1 million API calls per month free, then $0.05 per 10,000 calls

For Qlarius: **Essentially free** (4 parameters, minimal API calls due to caching)

---

## Quick Reference

```bash
# List all Qlarius secrets
aws ssm get-parameters-by-path --path "/qlarius" --recursive --region us-east-1

# Update a secret
aws ssm put-parameter --name "/qlarius/twilio/auth-token" --value "new-value" --type "SecureString" --overwrite --region us-east-1

# Delete a secret (careful!)
aws ssm delete-parameter --name "/qlarius/twilio/account-sid" --region us-east-1

# Test from Elixir console
Qlarius.Secrets.fetch_twilio_config_no_cache()
```

---

## Support

If you encounter issues not covered here, check:

1. AWS CloudTrail logs for API call failures
2. Kubernetes pod logs: `kubectl logs deployment/qlarius`
3. Elixir console: `kubectl exec -it deployment/qlarius -- /app/bin/qlarius remote`

For Twilio-specific issues, see `docs/phone_auth_implementation.md`.

