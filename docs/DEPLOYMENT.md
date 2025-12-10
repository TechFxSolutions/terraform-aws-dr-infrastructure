# Deployment Guide

Complete step-by-step guide for deploying the AWS Disaster Recovery infrastructure.

## Prerequisites Checklist

Before starting deployment, ensure you have:

- [ ] AWS Account with appropriate permissions
- [ ] AWS CLI installed and configured
- [ ] Terraform >= 1.6.0 installed
- [ ] Git installed
- [ ] GitHub repository cloned
- [ ] AWS credentials configured (see [AWS Credentials Setup](AWS_CREDENTIALS_SETUP.md))

## Verify Prerequisites

```bash
# Check Terraform version
terraform version

# Check AWS CLI version
aws --version

# Verify AWS credentials
aws sts get-caller-identity

# Check Git version
git --version
```

## Deployment Overview

The deployment follows this sequence:

1. **Global Resources** (IAM, S3 backend)
2. **Primary Region** (Active infrastructure)
3. **Secondary Region** (Passive infrastructure)
4. **DNS Configuration** (Route 53 failover)
5. **Verification** (Health checks and testing)

## Step-by-Step Deployment

### Step 1: Clone Repository

```bash
git clone https://github.com/TechFxSolutions/terraform-aws-dr-infrastructure.git
cd terraform-aws-dr-infrastructure
```

### Step 2: Configure Variables

#### Create terraform.tfvars for Primary Region

```bash
cd environments/primary
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
# Region Configuration
aws_region = "us-east-1"
environment = "primary"

# Network Configuration
vpc_cidr = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]

# Compute Configuration
web_instance_type = "t2.micro"
app_instance_type = "t2.micro"
web_instance_count = 2
app_instance_count = 2

# Database Configuration
db_instance_class = "db.t2.micro"
db_engine = "postgres"
db_engine_version = "15.3"
db_allocated_storage = 20
db_name = "appdb"
db_username = "dbadmin"
# db_password will be generated automatically

# Tags
project_name = "terraform-dr-infrastructure"
owner = "your-name"
cost_center = "engineering"
```

#### Create terraform.tfvars for Secondary Region

```bash
cd ../secondary
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
# Region Configuration
aws_region = "us-west-2"
environment = "secondary"

# Network Configuration
vpc_cidr = "10.1.0.0/16"
availability_zones = ["us-west-2a", "us-west-2b"]

# Compute Configuration (can be minimal for passive)
web_instance_type = "t2.micro"
app_instance_type = "t2.micro"
web_instance_count = 1  # Minimal for standby
app_instance_count = 1  # Minimal for standby

# Database Configuration
db_instance_class = "db.t2.micro"
db_engine = "postgres"
db_engine_version = "15.3"
db_allocated_storage = 20
db_name = "appdb"
db_username = "dbadmin"
# Will replicate from primary

# Tags
project_name = "terraform-dr-infrastructure"
owner = "your-name"
cost_center = "engineering"
```

### Step 3: Deploy Global Resources

#### S3 Backend for Terraform State

```bash
cd ../../global/s3-backend
terraform init
terraform plan
terraform apply
```

This creates:
- S3 bucket for Terraform state
- DynamoDB table for state locking
- KMS key for encryption

**Output**: Note the S3 bucket name and DynamoDB table name.

#### Global IAM Resources

```bash
cd ../iam
terraform init
terraform plan
terraform apply
```

This creates:
- IAM roles for EC2 instances
- IAM policies for services
- Service-linked roles

### Step 4: Deploy Primary Region

```bash
cd ../../environments/primary

# Initialize Terraform with remote backend
terraform init \
  -backend-config="bucket=YOUR_STATE_BUCKET" \
  -backend-config="key=primary/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=YOUR_LOCK_TABLE"

# Review the plan
terraform plan -out=tfplan

# Apply the configuration
terraform apply tfplan
```

**Deployment Time**: ~15-20 minutes

**Resources Created**:
- VPC with subnets, route tables, gateways
- Security groups and NACLs
- EC2 instances (web and app tiers)
- Application Load Balancer
- RDS database (Multi-AZ)
- CloudWatch alarms and dashboards
- S3 buckets for logs and backups

**Outputs**: Save these values:
```bash
terraform output > primary-outputs.txt
```

### Step 5: Deploy Secondary Region

```bash
cd ../secondary

# Initialize Terraform with remote backend
terraform init \
  -backend-config="bucket=YOUR_STATE_BUCKET" \
  -backend-config="key=secondary/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=YOUR_LOCK_TABLE"

# Review the plan
terraform plan -out=tfplan

# Apply the configuration
terraform apply tfplan
```

**Deployment Time**: ~15-20 minutes

**Resources Created**:
- Identical infrastructure to primary (in standby mode)
- RDS read replica from primary region
- Minimal EC2 capacity (can be stopped)

**Outputs**: Save these values:
```bash
terraform output > secondary-outputs.txt
```

### Step 6: Configure DNS Failover

```bash
cd ../../global/route53

# Update variables with ALB endpoints from outputs
terraform init
terraform plan
terraform apply
```

This creates:
- Route 53 hosted zone
- Health checks for primary region
- Failover routing policy
- DNS records

### Step 7: Verification

#### Verify Primary Region

```bash
# Check EC2 instances
aws ec2 describe-instances \
  --region us-east-1 \
  --filters "Name=tag:Environment,Values=primary" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress]' \
  --output table

# Check RDS instance
aws rds describe-db-instances \
  --region us-east-1 \
  --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus,Endpoint.Address]' \
  --output table

# Check Load Balancer
aws elbv2 describe-load-balancers \
  --region us-east-1 \
  --query 'LoadBalancers[*].[LoadBalancerName,State.Code,DNSName]' \
  --output table

# Test application endpoint
curl -I http://YOUR_ALB_DNS_NAME
```

#### Verify Secondary Region

```bash
# Check EC2 instances
aws ec2 describe-instances \
  --region us-west-2 \
  --filters "Name=tag:Environment,Values=secondary" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress]' \
  --output table

# Check RDS read replica
aws rds describe-db-instances \
  --region us-west-2 \
  --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus,ReadReplicaSourceDBInstanceIdentifier]' \
  --output table
```

#### Verify DNS Configuration

```bash
# Check Route 53 health checks
aws route53 get-health-check-status \
  --health-check-id YOUR_HEALTH_CHECK_ID

# Test DNS resolution
dig YOUR_DOMAIN_NAME
nslookup YOUR_DOMAIN_NAME
```

### Step 8: Post-Deployment Configuration

#### Configure Application

```bash
# SSH to web tier instance (via bastion)
ssh -i your-key.pem ec2-user@BASTION_IP

# Deploy application code
# Configure environment variables
# Start application services
```

#### Configure Database

```bash
# Connect to RDS
psql -h YOUR_RDS_ENDPOINT -U dbadmin -d appdb

# Run migrations
# Load initial data
# Configure replication monitoring
```

#### Configure Monitoring

```bash
# Verify CloudWatch alarms
aws cloudwatch describe-alarms \
  --region us-east-1 \
  --query 'MetricAlarms[*].[AlarmName,StateValue]' \
  --output table

# Check CloudWatch Logs
aws logs describe-log-groups \
  --region us-east-1 \
  --output table
```

## Deployment Scripts

### Automated Deployment Script

Create `scripts/deploy-all.sh`:

```bash
#!/bin/bash
set -e

echo "Starting full deployment..."

# Deploy global resources
echo "Deploying S3 backend..."
cd global/s3-backend && terraform init && terraform apply -auto-approve

echo "Deploying IAM resources..."
cd ../iam && terraform init && terraform apply -auto-approve

# Deploy primary region
echo "Deploying primary region..."
cd ../../environments/primary
terraform init -backend-config="bucket=$STATE_BUCKET"
terraform apply -auto-approve

# Deploy secondary region
echo "Deploying secondary region..."
cd ../secondary
terraform init -backend-config="bucket=$STATE_BUCKET"
terraform apply -auto-approve

# Deploy Route 53
echo "Deploying DNS configuration..."
cd ../../global/route53
terraform init && terraform apply -auto-approve

echo "Deployment complete!"
```

Make it executable:
```bash
chmod +x scripts/deploy-all.sh
```

### Deployment Validation Script

Create `scripts/validate-deployment.sh`:

```bash
#!/bin/bash

echo "Validating deployment..."

# Check primary region
echo "Checking primary region (us-east-1)..."
aws ec2 describe-instances --region us-east-1 --filters "Name=tag:Environment,Values=primary" --query 'Reservations[*].Instances[*].State.Name' --output text

# Check secondary region
echo "Checking secondary region (us-west-2)..."
aws ec2 describe-instances --region us-west-2 --filters "Name=tag:Environment,Values=secondary" --query 'Reservations[*].Instances[*].State.Name' --output text

# Check RDS
echo "Checking RDS instances..."
aws rds describe-db-instances --region us-east-1 --query 'DBInstances[*].DBInstanceStatus' --output text

# Check health checks
echo "Checking Route 53 health..."
aws route53 get-health-check-status --health-check-id $HEALTH_CHECK_ID

echo "Validation complete!"
```

## Troubleshooting

### Common Issues

#### Issue: Terraform State Lock

**Error**: "Error locking state: ConditionalCheckFailedException"

**Solution**:
```bash
# Force unlock (use with caution)
terraform force-unlock LOCK_ID
```

#### Issue: Insufficient Capacity

**Error**: "InsufficientInstanceCapacity"

**Solution**:
- Try different availability zone
- Use different instance type
- Wait and retry

#### Issue: RDS Creation Timeout

**Error**: "timeout while waiting for state to become 'available'"

**Solution**:
- RDS creation can take 10-15 minutes
- Check AWS console for detailed status
- Verify security group rules

#### Issue: VPC Limit Exceeded

**Error**: "VpcLimitExceeded"

**Solution**:
```bash
# Check VPC limit
aws ec2 describe-account-attributes --attribute-names max-vpcs

# Request limit increase via AWS Support
```

### Rollback Procedure

If deployment fails:

```bash
# Destroy in reverse order
cd environments/secondary
terraform destroy -auto-approve

cd ../primary
terraform destroy -auto-approve

cd ../../global/route53
terraform destroy -auto-approve

cd ../iam
terraform destroy -auto-approve

cd ../s3-backend
terraform destroy -auto-approve
```

## Cost Monitoring

### Check Current Costs

```bash
# Get cost and usage
aws ce get-cost-and-usage \
  --time-period Start=2025-12-01,End=2025-12-31 \
  --granularity MONTHLY \
  --metrics "UnblendedCost" \
  --group-by Type=SERVICE
```

### Set Up Budget Alerts

```bash
# Create budget
aws budgets create-budget \
  --account-id YOUR_ACCOUNT_ID \
  --budget file://budget.json \
  --notifications-with-subscribers file://notifications.json
```

## Next Steps

After successful deployment:

1. **Configure Application**: Deploy your application code
2. **Test Failover**: Perform DR testing (see [RUNBOOK.md](RUNBOOK.md))
3. **Set Up Monitoring**: Configure alerts and dashboards
4. **Document**: Update runbooks with environment-specific details
5. **Security Audit**: Run security scans and compliance checks

## Additional Resources

- [Architecture Documentation](ARCHITECTURE.md)
- [DR Runbook](RUNBOOK.md)
- [SOC-2 Compliance](SOC2_COMPLIANCE.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)

---

**Support**: For deployment issues, check [Troubleshooting Guide](TROUBLESHOOTING.md) or open an issue.
