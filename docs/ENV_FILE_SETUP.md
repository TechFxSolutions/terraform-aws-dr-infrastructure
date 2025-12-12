# Environment File (.env) Setup Guide

This guide explains how to configure AWS credentials using the `.env` file for secure and convenient authentication.

## 📋 Table of Contents

- [Overview](#overview)
- [Quick Setup](#quick-setup)
- [Configuration Options](#configuration-options)
- [Security Best Practices](#security-best-practices)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

The `.env` file provides a convenient way to manage AWS credentials and project configuration without hardcoding sensitive information in scripts or committing them to version control.

### Benefits

✅ **Secure**: Credentials stored locally, never committed to Git  
✅ **Convenient**: Automatically loaded by deployment scripts  
✅ **Flexible**: Supports multiple authentication methods  
✅ **Portable**: Easy to share configuration (without credentials)  

---

## 🚀 Quick Setup

### Step 1: Copy the Example File

```bash
cp .env.example .env
```

### Step 2: Edit the .env File

Open `.env` in your text editor:

```bash
nano .env
# or
vim .env
# or
code .env
```

### Step 3: Add Your AWS Credentials

```bash
# AWS Access Credentials
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_DEFAULT_REGION=us-east-1
```

### Step 4: Verify Configuration

```bash
# Load the environment variables
source .env

# Test AWS credentials
aws sts get-caller-identity
```

**Expected Output:**
```json
{
    "UserId": "AIDAI...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

---

## ⚙️ Configuration Options

### Method 1: Access Keys (Recommended for Development)

```bash
# .env file
AWS_ACCESS_KEY_ID=your_access_key_here
AWS_SECRET_ACCESS_KEY=your_secret_key_here
AWS_DEFAULT_REGION=us-east-1
```

**How to Get Access Keys:**

1. Log in to AWS Console
2. Go to IAM → Users → Your User
3. Click "Security credentials" tab
4. Click "Create access key"
5. Download and save the credentials

### Method 2: AWS Profile

```bash
# .env file
AWS_PROFILE=your_profile_name
AWS_DEFAULT_REGION=us-east-1
```

**Setup AWS Profile:**

```bash
# Configure AWS CLI with named profile
aws configure --profile your_profile_name

# Verify profile
aws sts get-caller-identity --profile your_profile_name
```

### Method 3: Temporary Credentials (MFA/STS)

```bash
# .env file
AWS_ACCESS_KEY_ID=ASIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_SESSION_TOKEN=FwoGZXIvYXdzEBYaD...
AWS_DEFAULT_REGION=us-east-1
```

**Get Temporary Credentials:**

```bash
# Using MFA
aws sts get-session-token \
  --serial-number arn:aws:iam::123456789012:mfa/user \
  --token-code 123456

# Using assume role
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/MyRole \
  --role-session-name my-session
```

### Complete .env Example

```bash
# AWS Credentials
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_DEFAULT_REGION=us-east-1

# Optional: Session Token (for temporary credentials)
# AWS_SESSION_TOKEN=FwoGZXIvYXdzEBYaD...

# Optional: AWS Profile (alternative to access keys)
# AWS_PROFILE=production

# Terraform Backend (auto-populated after backend creation)
TF_STATE_BUCKET=terraform-dr-infrastructure-state-abc123
TF_STATE_LOCK_TABLE=terraform-dr-infrastructure-locks

# Project Configuration
PROJECT_NAME=terraform-dr-infrastructure
ENVIRONMENT=production

# Notification Email
ALARM_EMAIL=ops-team@example.com

# Optional: Debug Mode
# TF_LOG=DEBUG
# AWS_SDK_LOAD_CONFIG=1
```

---

## 🔒 Security Best Practices

### 1. Never Commit .env to Git

The `.gitignore` file already excludes `.env`:

```bash
# Verify .env is ignored
git status

# .env should NOT appear in the list
```

### 2. Use IAM Roles in Production

For production deployments, use IAM roles instead of access keys:

```bash
# EC2 Instance Role
# No credentials needed in .env

# Or use AWS SSO
aws sso login --profile production
```

### 3. Rotate Credentials Regularly

```bash
# Create new access key
aws iam create-access-key --user-name your-username

# Update .env with new credentials

# Delete old access key
aws iam delete-access-key \
  --access-key-id OLD_ACCESS_KEY_ID \
  --user-name your-username
```

### 4. Use Least Privilege

Create IAM user with minimal required permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "rds:*",
        "s3:*",
        "iam:*",
        "cloudwatch:*",
        "elasticloadbalancing:*",
        "autoscaling:*"
      ],
      "Resource": "*"
    }
  ]
}
```

### 5. Protect the .env File

```bash
# Set restrictive permissions
chmod 600 .env

# Verify permissions
ls -la .env
# Should show: -rw------- (only owner can read/write)
```

### 6. Use AWS Secrets Manager for Production

For production, consider using AWS Secrets Manager:

```bash
# Store credentials in Secrets Manager
aws secretsmanager create-secret \
  --name terraform-aws-credentials \
  --secret-string '{"access_key":"xxx","secret_key":"yyy"}'

# Retrieve in scripts
aws secretsmanager get-secret-value \
  --secret-id terraform-aws-credentials \
  --query SecretString --output text
```

---

## 🔧 Usage with Scripts

### Automatic Loading

All deployment scripts automatically load `.env`:

```bash
# Deploy script loads .env automatically
./scripts/deploy-all.sh

# Validation script loads .env automatically
./scripts/validate-deployment.sh

# Destroy script loads .env automatically
./scripts/destroy-all.sh
```

### Manual Loading

Load `.env` in your shell session:

```bash
# Load environment variables
source .env

# Or use export
set -a
source .env
set +a

# Verify loaded
echo $AWS_ACCESS_KEY_ID
```

### Using with Terraform

Terraform automatically uses AWS environment variables:

```bash
# Load .env
source .env

# Run Terraform commands
terraform init
terraform plan
terraform apply
```

---

## 🐛 Troubleshooting

### Issue: "AWS credentials not configured"

**Solution:**

```bash
# Check if .env exists
ls -la .env

# Load .env manually
source .env

# Verify credentials
aws sts get-caller-identity

# Check environment variables
echo $AWS_ACCESS_KEY_ID
echo $AWS_SECRET_ACCESS_KEY
```

### Issue: "Access Denied" errors

**Possible Causes:**

1. **Incorrect credentials**
   ```bash
   # Verify credentials
   aws sts get-caller-identity
   ```

2. **Insufficient permissions**
   ```bash
   # Check IAM user permissions
   aws iam list-attached-user-policies --user-name your-username
   ```

3. **Expired temporary credentials**
   ```bash
   # Get new temporary credentials
   aws sts get-session-token --serial-number arn:aws:iam::xxx:mfa/user --token-code 123456
   ```

### Issue: .env not loading automatically

**Solution:**

```bash
# Check script has source command
grep "source .env" scripts/deploy-all.sh

# Manually load before running
source .env
./scripts/deploy-all.sh
```

### Issue: Special characters in credentials

**Solution:**

```bash
# Wrap values in quotes if they contain special characters
AWS_SECRET_ACCESS_KEY="wJalr/XUtn+FEMI/K7MDENG/bPxRfiCY"
```

---

## 📚 Additional Resources

### AWS Documentation
- [AWS CLI Configuration](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)
- [IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [AWS Credentials](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html)

### Project Documentation
- [AWS Credentials Setup](AWS_CREDENTIALS_SETUP.md)
- [Deployment Guide](DEPLOYMENT.md)
- [Quick Reference](../QUICK_REFERENCE.md)

---

## 🔐 Security Checklist

Before deploying to production:

- [ ] `.env` file is in `.gitignore`
- [ ] `.env` has restrictive permissions (600)
- [ ] Using IAM user with least privilege
- [ ] MFA enabled on IAM user
- [ ] Access keys rotated regularly
- [ ] No credentials in code or scripts
- [ ] Using IAM roles for EC2 instances
- [ ] CloudTrail enabled for audit logging

---

## 💡 Tips

### Tip 1: Multiple Environments

Create separate `.env` files for different environments:

```bash
.env.development
.env.staging
.env.production
```

Load the appropriate one:

```bash
source .env.production
./scripts/deploy-all.sh
```

### Tip 2: Team Sharing

Share `.env.example` with your team:

```bash
# Team member copies and configures
cp .env.example .env
# Edit with their credentials
```

### Tip 3: CI/CD Integration

For CI/CD, use GitHub Secrets instead of `.env`:

```yaml
# .github/workflows/terraform-ci.yml
env:
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

---

**Last Updated**: December 11, 2025
