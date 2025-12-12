# Common Issues and Quick Fixes

Quick solutions to common problems you might encounter.

## 🚨 Permission Denied on Scripts

### Problem
```bash
./scripts/deploy-all.sh
# Error: Permission denied
```

### Solution

**Option 1: Make all scripts executable at once**
```bash
chmod +x scripts/*.sh
```

**Option 2: Use the helper script**
```bash
bash scripts/make-executable.sh
```

**Option 3: Run with bash directly**
```bash
bash scripts/deploy-all.sh
```

**Option 4: Fix individual script**
```bash
chmod +x scripts/deploy-all.sh
./scripts/deploy-all.sh
```

### Why This Happens
Git doesn't preserve executable permissions when cloning. You need to set them manually after cloning.

---

## 🔑 AWS Credentials Not Found

### Problem
```bash
./scripts/deploy-all.sh
# Error: AWS credentials not configured
```

### Solution

**Option 1: Use .env file (Recommended)**
```bash
# Create .env from example
cp .env.example .env

# Edit and add your credentials
nano .env

# Add these lines:
AWS_ACCESS_KEY_ID=your_access_key_here
AWS_SECRET_ACCESS_KEY=your_secret_key_here
AWS_DEFAULT_REGION=us-east-1

# Load manually if needed
source .env

# Verify
aws sts get-caller-identity
```

**Option 2: Use AWS CLI configure**
```bash
aws configure
# Enter: Access Key ID, Secret Access Key, Region, Output format
```

**Option 3: Export environment variables**
```bash
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_DEFAULT_REGION=us-east-1
```

---

## 📝 terraform.tfvars Not Found

### Problem
```bash
terraform apply
# Error: terraform.tfvars not found
```

### Solution
```bash
# Copy example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your settings
nano terraform.tfvars

# Required fields:
# - project_name
# - environment
# - vpc_cidr
# - alarm_email
```

---

## 🔒 Access Denied Errors

### Problem
```bash
terraform apply
# Error: AccessDenied: User is not authorized to perform...
```

### Solution

**Check IAM permissions:**
```bash
# Verify current user
aws sts get-caller-identity

# Check attached policies
aws iam list-attached-user-policies --user-name YOUR_USERNAME

# Check inline policies
aws iam list-user-policies --user-name YOUR_USERNAME
```

**Required IAM permissions:**
- EC2 (full access)
- RDS (full access)
- S3 (full access)
- IAM (full access)
- VPC (full access)
- CloudWatch (full access)
- Auto Scaling (full access)
- Elastic Load Balancing (full access)

**Quick fix - Attach AdministratorAccess (for testing only):**
```bash
aws iam attach-user-policy \
  --user-name YOUR_USERNAME \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

---

## 🌐 Region Not Available

### Problem
```bash
terraform apply
# Error: The requested Availability Zone is not available
```

### Solution
```bash
# Check available AZs in your region
aws ec2 describe-availability-zones --region us-east-1

# Update terraform.tfvars with available AZs
availability_zones = ["us-east-1a", "us-east-1b"]
```

---

## 💾 S3 Bucket Already Exists

### Problem
```bash
terraform apply
# Error: BucketAlreadyExists: The requested bucket name is not available
```

### Solution

**Option 1: Use unique bucket name**
```bash
# Edit terraform.tfvars
project_name = "myproject-unique-12345"
```

**Option 2: Delete existing bucket**
```bash
# List buckets
aws s3 ls

# Delete bucket (if you own it)
aws s3 rb s3://bucket-name --force
```

---

## 🔄 State Lock Error

### Problem
```bash
terraform apply
# Error: Error acquiring the state lock
```

### Solution

**Option 1: Wait for lock to release**
```bash
# Wait a few minutes and try again
terraform apply
```

**Option 2: Force unlock (use with caution)**
```bash
# Get lock ID from error message
terraform force-unlock LOCK_ID
```

**Option 3: Check DynamoDB table**
```bash
# List locks
aws dynamodb scan --table-name terraform-state-locks

# Delete specific lock (if stuck)
aws dynamodb delete-item \
  --table-name terraform-state-locks \
  --key '{"LockID":{"S":"LOCK_ID"}}'
```

---

## 🗄️ RDS Instance Already Exists

### Problem
```bash
terraform apply
# Error: DBInstanceAlreadyExists
```

### Solution

**Option 1: Import existing instance**
```bash
terraform import module.database.aws_db_instance.main my-db-instance
```

**Option 2: Use different identifier**
```bash
# Edit terraform.tfvars
db_identifier = "mydb-unique-name"
```

**Option 3: Delete existing instance**
```bash
aws rds delete-db-instance \
  --db-instance-identifier my-db-instance \
  --skip-final-snapshot
```

---

## 🔌 VPC Limit Exceeded

### Problem
```bash
terraform apply
# Error: VpcLimitExceeded
```

### Solution

**Check VPC limit:**
```bash
# List all VPCs
aws ec2 describe-vpcs

# Request limit increase
# Go to AWS Console > Service Quotas > Amazon VPC
```

**Delete unused VPCs:**
```bash
# Delete VPC (must delete dependencies first)
aws ec2 delete-vpc --vpc-id vpc-xxxxx
```

---

## 📊 CloudWatch Alarm Limit

### Problem
```bash
terraform apply
# Error: LimitExceededException: The maximum number of alarms has been reached
```

### Solution
```bash
# List all alarms
aws cloudwatch describe-alarms

# Delete unused alarms
aws cloudwatch delete-alarms --alarm-names alarm1 alarm2

# Or request limit increase in AWS Console
```

---

## 🔐 KMS Key Not Found

### Problem
```bash
terraform apply
# Error: KMS key not found
```

### Solution
```bash
# List KMS keys
aws kms list-keys

# Create new key if needed
aws kms create-key --description "Terraform encryption key"

# Update terraform.tfvars with key ARN
kms_key_id = "arn:aws:kms:us-east-1:123456789012:key/xxxxx"
```

---

## 🌍 DNS Resolution Issues

### Problem
```bash
# Cannot access application via ALB DNS
```

### Solution
```bash
# Get ALB DNS name
terraform output alb_dns_name

# Test DNS resolution
nslookup ALB_DNS_NAME

# Test connectivity
curl -I http://ALB_DNS_NAME

# Check security groups
aws ec2 describe-security-groups --group-ids sg-xxxxx
```

---

## 🔍 Terraform State Corruption

### Problem
```bash
terraform plan
# Error: state snapshot was created by Terraform v1.x.x
```

### Solution

**Option 1: Upgrade Terraform**
```bash
# Check current version
terraform version

# Upgrade to latest
# Download from https://www.terraform.io/downloads
```

**Option 2: Restore from backup**
```bash
# List state backups
aws s3 ls s3://terraform-state-bucket/

# Restore backup
aws s3 cp s3://terraform-state-bucket/terraform.tfstate.backup \
  s3://terraform-state-bucket/terraform.tfstate
```

---

## 💸 Unexpected Costs

### Problem
```bash
# AWS bill higher than expected
```

### Solution

**Check costs:**
```bash
# Get cost and usage
aws ce get-cost-and-usage \
  --time-period Start=2025-12-01,End=2025-12-31 \
  --granularity MONTHLY \
  --metrics "UnblendedCost"
```

**Common cost culprits:**
- NAT Gateways ($0.045/hour = ~$32/month each)
- RDS instances running 24/7
- EBS volumes
- Data transfer
- Load Balancers

**Reduce costs:**
```bash
# Stop non-production instances
aws ec2 stop-instances --instance-ids i-xxxxx

# Delete unused resources
./scripts/destroy-all.sh
```

---

## 🔄 Deployment Stuck

### Problem
```bash
terraform apply
# Stuck at "Still creating..." for 30+ minutes
```

### Solution

**Option 1: Wait (some resources take time)**
- RDS instances: 10-15 minutes
- NAT Gateways: 5-10 minutes
- ALB: 5-10 minutes

**Option 2: Check AWS Console**
- Verify resource is actually being created
- Check for errors in CloudFormation (if using)

**Option 3: Cancel and retry**
```bash
# Press Ctrl+C to cancel
# Then retry
terraform apply
```

---

## 📞 Getting More Help

### Check Documentation
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [Quick Reference](../QUICK_REFERENCE.md)
- [Deployment Guide](DEPLOYMENT.md)

### AWS Resources
- [AWS Service Health Dashboard](https://status.aws.amazon.com/)
- [AWS Support Center](https://console.aws.amazon.com/support/)
- [AWS Forums](https://forums.aws.amazon.com/)

### Terraform Resources
- [Terraform Documentation](https://www.terraform.io/docs)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Community Forum](https://discuss.hashicorp.com/c/terraform-core)

### Project Support
- [GitHub Issues](https://github.com/TechFxSolutions/terraform-aws-dr-infrastructure/issues)
- [Project Documentation](../README.md)

---

**Last Updated**: December 11, 2025
