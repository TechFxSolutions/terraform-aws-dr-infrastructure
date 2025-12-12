# Fix: AWS Credentials Not Configured (.env file)

If you're getting the error "AWS credentials are not configured" even though you're using the `.env` file, follow these steps.

## 🔍 Quick Diagnosis

Run the diagnostic tool to identify the issue:

```bash
# Make it executable
chmod +x scripts/test-credentials.sh

# Run diagnostic
./scripts/test-credentials.sh
```

This will tell you exactly what's wrong.

---

## 🛠️ Step-by-Step Fix

### Step 1: Verify .env File Exists

```bash
# Check if .env exists
ls -la .env

# If not found, create it
cp .env.example .env
```

**Expected output:**
```
-rw------- 1 user user 1234 Dec 11 10:00 .env
```

---

### Step 2: Check .env File Content

```bash
# View .env file (be careful - contains sensitive data!)
cat .env
```

**Your .env should look like this:**

```bash
# AWS Credentials Configuration
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_DEFAULT_REGION=us-east-1
```

**Common mistakes:**

❌ **Still has placeholder values:**
```bash
AWS_ACCESS_KEY_ID=your_access_key_here  # WRONG!
```

❌ **Missing equals sign:**
```bash
AWS_ACCESS_KEY_ID AKIAIOSFODNN7EXAMPLE  # WRONG!
```

❌ **Has spaces around equals:**
```bash
AWS_ACCESS_KEY_ID = AKIAIOSFODNN7EXAMPLE  # WRONG!
```

❌ **Values are quoted (sometimes causes issues):**
```bash
AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"  # Try without quotes
```

✅ **Correct format:**
```bash
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_DEFAULT_REGION=us-east-1
```

---

### Step 3: Get Your AWS Credentials

If you don't have AWS credentials yet:

#### Option A: AWS Console (Recommended)

1. **Log in to AWS Console**: https://console.aws.amazon.com/
2. **Go to IAM**: Services → IAM
3. **Click on Users** → Select your user (or create new user)
4. **Security credentials tab**
5. **Click "Create access key"**
6. **Choose "Command Line Interface (CLI)"**
7. **Download or copy the credentials**

#### Option B: AWS CLI (if already configured)

```bash
# If you already have AWS CLI configured
cat ~/.aws/credentials

# Copy the values to .env
```

---

### Step 4: Edit .env File

```bash
# Open .env in your editor
nano .env

# Or use vim
vim .env

# Or use VS Code
code .env
```

**Replace the placeholder values:**

```bash
# Before (placeholder values)
AWS_ACCESS_KEY_ID=your_access_key_here
AWS_SECRET_ACCESS_KEY=your_secret_key_here

# After (your actual credentials)
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_DEFAULT_REGION=us-east-1
```

**Save the file:**
- nano: `Ctrl+O`, `Enter`, `Ctrl+X`
- vim: `Esc`, `:wq`, `Enter`
- VS Code: `Ctrl+S` or `Cmd+S`

---

### Step 5: Verify File Permissions

```bash
# Set correct permissions (only you can read/write)
chmod 600 .env

# Verify
ls -la .env
# Should show: -rw------- (600)
```

---

### Step 6: Test Credentials Manually

```bash
# Load .env file
source .env

# Check if variables are loaded
echo $AWS_ACCESS_KEY_ID
# Should print your access key (not "your_access_key_here")

# Test with AWS CLI
aws sts get-caller-identity
```

**Expected output:**
```json
{
    "UserId": "AIDAI...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

**If you get an error:**
```
An error occurred (InvalidClientTokenId) when calling the GetCallerIdentity operation: The security token included in the request is invalid.
```

This means:
- ❌ Access key is incorrect
- ❌ Access key has been deleted/deactivated
- ❌ You copied the wrong credentials

**Fix:** Go back to AWS Console and verify/regenerate credentials.

---

### Step 7: Run Deployment Script

```bash
# The script should now work
./scripts/deploy-all.sh
```

The script will automatically load `.env` and use your credentials.

---

## 🔧 Alternative: Manual Loading

If the script still doesn't load `.env` automatically:

```bash
# Load .env manually before running script
source .env

# Verify it's loaded
echo $AWS_ACCESS_KEY_ID

# Then run deployment
./scripts/deploy-all.sh
```

---

## 🐛 Still Not Working?

### Check 1: File Encoding

```bash
# Check file encoding
file .env
# Should say: ASCII text

# If it says something else, recreate the file
rm .env
cp .env.example .env
nano .env  # Add credentials again
```

### Check 2: Hidden Characters

```bash
# Check for hidden characters
cat -A .env

# Should show clean lines like:
# AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE$
# AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY$

# If you see ^M or other weird characters, recreate the file
```

### Check 3: Script Loading Logic

```bash
# Check if deploy script has the source command
grep "source .env" scripts/deploy-all.sh

# Should show:
# source .env
```

### Check 4: Run Diagnostic Tool

```bash
# Run the comprehensive diagnostic
chmod +x scripts/test-credentials.sh
./scripts/test-credentials.sh

# This will tell you exactly what's wrong
```

---

## 📋 Complete Working Example

Here's a complete working `.env` file example:

```bash
# AWS Credentials Configuration
# IMPORTANT: Replace these with your actual AWS credentials

# AWS Access Credentials (REQUIRED)
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_DEFAULT_REGION=us-east-1

# Optional: AWS Session Token (for temporary credentials)
# AWS_SESSION_TOKEN=FwoGZXIvYXdzEBYaD...

# Optional: AWS Profile (alternative to access keys)
# AWS_PROFILE=default

# Terraform Backend Configuration (auto-populated after backend creation)
TF_STATE_BUCKET=
TF_STATE_LOCK_TABLE=

# Project Configuration
PROJECT_NAME=terraform-dr-infrastructure
ENVIRONMENT=production

# Notification Email (for CloudWatch alarms)
ALARM_EMAIL=your-email@example.com

# Optional: Enable debug mode
# TF_LOG=DEBUG
# AWS_SDK_LOAD_CONFIG=1
```

---

## ✅ Verification Checklist

Before running deployment, verify:

- [ ] `.env` file exists in project root
- [ ] File has correct permissions (600)
- [ ] `AWS_ACCESS_KEY_ID` is set (not placeholder)
- [ ] `AWS_SECRET_ACCESS_KEY` is set (not placeholder)
- [ ] `AWS_DEFAULT_REGION` is set
- [ ] No quotes around values
- [ ] No spaces around `=` sign
- [ ] File encoding is ASCII/UTF-8
- [ ] `source .env` loads variables correctly
- [ ] `aws sts get-caller-identity` works

---

## 🆘 Emergency Workaround

If `.env` still doesn't work, use environment variables directly:

```bash
# Export credentials directly
export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
export AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
export AWS_DEFAULT_REGION=us-east-1

# Verify
aws sts get-caller-identity

# Run deployment
./scripts/deploy-all.sh
```

Or use AWS CLI configuration:

```bash
# Configure AWS CLI
aws configure

# Enter your credentials when prompted
# Then run deployment
./scripts/deploy-all.sh
```

---

## 📞 Need More Help?

1. **Run diagnostic tool**: `./scripts/test-credentials.sh`
2. **Check documentation**: `docs/ENV_FILE_SETUP.md`
3. **Common issues**: `docs/COMMON_ISSUES.md`
4. **Open GitHub issue**: Include output from diagnostic tool

---

**Last Updated**: December 11, 2025
