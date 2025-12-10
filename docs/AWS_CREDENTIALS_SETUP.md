# AWS Credentials Setup Guide

This guide provides comprehensive instructions for setting up AWS credentials for the Terraform DR infrastructure project.

## Prerequisites

- AWS Account (Free Tier eligible)
- AWS CLI installed
- Terminal/Command Prompt access

## Installation

### AWS CLI Installation

#### macOS
```bash
brew install awscli
```

#### Linux
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

#### Windows
Download and run the AWS CLI MSI installer from:
https://awscli.amazonaws.com/AWSCLIV2.msi

### Verify Installation
```bash
aws --version
# Expected output: aws-cli/2.x.x Python/3.x.x ...
```

## Creating AWS IAM User

### Step 1: Access IAM Console

1. Log in to [AWS Console](https://console.aws.amazon.com/)
2. Navigate to **IAM** (Identity and Access Management)
3. Click **Users** in the left sidebar
4. Click **Add users**

### Step 2: Configure User

1. **User name**: `terraform-dr-admin`
2. **Access type**: Select **Programmatic access**
3. Click **Next: Permissions**

### Step 3: Set Permissions

**Option A: Administrator Access (Recommended for Testing)**
1. Click **Attach existing policies directly**
2. Search and select **AdministratorAccess**
3. Click **Next: Tags**

**Option B: Least-Privilege Access (Production)**
Create a custom policy with these permissions:
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
        "cloudtrail:*",
        "logs:*",
        "elasticloadbalancing:*",
        "autoscaling:*",
        "route53:*",
        "kms:*",
        "secretsmanager:*",
        "dynamodb:*"
      ],
      "Resource": "*"
    }
  ]
}
```

### Step 4: Add Tags (Optional)
```
Key: Project, Value: terraform-dr-infrastructure
Key: Environment, Value: production
Key: ManagedBy, Value: terraform
```

### Step 5: Review and Create

1. Review the configuration
2. Click **Create user**
3. **IMPORTANT**: Download the CSV file or copy:
   - Access Key ID
   - Secret Access Key

⚠️ **Security Warning**: This is the only time you can view the secret access key. Store it securely!

## Configuring AWS CLI

### Method 1: Interactive Configuration (Recommended)

```bash
aws configure
```

You'll be prompted for:
```
AWS Access Key ID [None]: YOUR_ACCESS_KEY_ID
AWS Secret Access Key [None]: YOUR_SECRET_ACCESS_KEY
Default region name [None]: us-east-1
Default output format [None]: json
```

### Method 2: Environment Variables

```bash
# Linux/macOS
export AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="YOUR_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION="us-east-1"

# Windows (PowerShell)
$env:AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY_ID"
$env:AWS_SECRET_ACCESS_KEY="YOUR_SECRET_ACCESS_KEY"
$env:AWS_DEFAULT_REGION="us-east-1"
```

### Method 3: AWS Credentials File

Create/edit `~/.aws/credentials`:
```ini
[default]
aws_access_key_id = YOUR_ACCESS_KEY_ID
aws_secret_access_key = YOUR_SECRET_ACCESS_KEY
```

Create/edit `~/.aws/config`:
```ini
[default]
region = us-east-1
output = json
```

## Multiple AWS Profiles

For managing multiple environments:

### Configure Profiles
```bash
aws configure --profile primary
aws configure --profile secondary
```

### Use Profiles
```bash
# With AWS CLI
aws s3 ls --profile primary

# With Terraform
export AWS_PROFILE=primary
terraform plan
```

### Credentials File with Profiles
```ini
[default]
aws_access_key_id = DEFAULT_KEY
aws_secret_access_key = DEFAULT_SECRET

[primary]
aws_access_key_id = PRIMARY_KEY
aws_secret_access_key = PRIMARY_SECRET

[secondary]
aws_access_key_id = SECONDARY_KEY
aws_secret_access_key = SECONDARY_SECRET
```

## Verification

### Test AWS Credentials
```bash
# Get caller identity
aws sts get-caller-identity

# Expected output:
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/terraform-dr-admin"
}
```

### Test AWS Access
```bash
# List S3 buckets
aws s3 ls

# List EC2 instances
aws ec2 describe-instances --region us-east-1

# List RDS instances
aws rds describe-db-instances --region us-east-1
```

## Terraform AWS Provider Configuration

### Basic Configuration
```hcl
provider "aws" {
  region = var.aws_region
  
  # Credentials are automatically loaded from:
  # 1. Environment variables
  # 2. Shared credentials file (~/.aws/credentials)
  # 3. IAM role (if running on EC2)
}
```

### Multi-Region Configuration
```hcl
# Primary region
provider "aws" {
  alias  = "primary"
  region = "us-east-1"
}

# Secondary region
provider "aws" {
  alias  = "secondary"
  region = "us-west-2"
}
```

### With Profile
```hcl
provider "aws" {
  region  = "us-east-1"
  profile = "primary"
}
```

## Security Best Practices

### 1. Never Commit Credentials
- Add credentials files to `.gitignore`
- Never hardcode credentials in Terraform files
- Use environment variables or AWS credentials file

### 2. Enable MFA
```bash
# Configure MFA device in IAM console
# Use MFA with AWS CLI
aws sts get-session-token --serial-number arn:aws:iam::ACCOUNT_ID:mfa/USER --token-code MFA_CODE
```

### 3. Rotate Access Keys Regularly
```bash
# Create new access key
aws iam create-access-key --user-name terraform-dr-admin

# Delete old access key
aws iam delete-access-key --access-key-id OLD_KEY_ID --user-name terraform-dr-admin
```

### 4. Use IAM Roles (When Possible)
For EC2 instances or CI/CD pipelines, use IAM roles instead of access keys.

### 5. Least Privilege Principle
Grant only the permissions required for the specific tasks.

## Troubleshooting

### Issue: "Unable to locate credentials"
**Solution**: Verify credentials are configured:
```bash
cat ~/.aws/credentials
aws configure list
```

### Issue: "Access Denied" errors
**Solution**: Check IAM permissions:
```bash
aws iam get-user
aws iam list-attached-user-policies --user-name terraform-dr-admin
```

### Issue: "Region not specified"
**Solution**: Set default region:
```bash
aws configure set region us-east-1
```

### Issue: Credentials expired
**Solution**: Refresh credentials or create new access keys.

## CI/CD Integration

### GitHub Actions
```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: us-east-1
```

### Store Secrets in GitHub
1. Go to repository **Settings** → **Secrets and variables** → **Actions**
2. Add secrets:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

## Additional Resources

- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Free Tier](https://aws.amazon.com/free/)

## Support

For issues with AWS credentials setup:
1. Check [AWS CLI Troubleshooting](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-troubleshooting.html)
2. Review [IAM Troubleshooting](https://docs.aws.amazon.com/IAM/latest/UserGuide/troubleshoot.html)
3. Open an issue in this repository

---

**Next Steps**: After configuring credentials, proceed to [Deployment Guide](DEPLOYMENT.md)
