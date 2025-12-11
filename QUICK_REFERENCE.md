# Quick Reference Guide

Fast reference for common tasks and commands.

## 🚀 Quick Commands

### Initial Setup
```bash
# Clone and setup
git clone https://github.com/TechFxSolutions/terraform-aws-dr-infrastructure.git
cd terraform-aws-dr-infrastructure
aws configure

# Copy and edit config files
cp environments/primary/terraform.tfvars.example environments/primary/terraform.tfvars
cp environments/secondary/terraform.tfvars.example environments/secondary/terraform.tfvars
```

### Deployment
```bash
# Full automated deployment
./scripts/deploy-all.sh

# Manual step-by-step
cd global/s3-backend && terraform init && terraform apply
cd ../iam && terraform init && terraform apply
cd ../../environments/primary && terraform init && terraform apply
cd ../secondary && terraform init && terraform apply
```

### Validation
```bash
# Validate deployment
./scripts/validate-deployment.sh

# Check specific region
cd environments/primary && terraform plan
cd environments/secondary && terraform plan
```

### Destruction
```bash
# Destroy all infrastructure
./scripts/destroy-all.sh

# Destroy specific region
cd environments/secondary && terraform destroy
cd environments/primary && terraform destroy
```

---

## 📋 Common Terraform Commands

### Initialization
```bash
terraform init                    # Initialize working directory
terraform init -upgrade           # Upgrade providers
terraform init -reconfigure       # Reconfigure backend
```

### Planning
```bash
terraform plan                    # Show execution plan
terraform plan -out=tfplan        # Save plan to file
terraform plan -target=module.x   # Plan specific module
```

### Applying
```bash
terraform apply                   # Apply changes
terraform apply tfplan            # Apply saved plan
terraform apply -auto-approve     # Skip confirmation
terraform apply -target=module.x  # Apply specific module
```

### Destroying
```bash
terraform destroy                 # Destroy all resources
terraform destroy -auto-approve   # Skip confirmation
terraform destroy -target=module.x # Destroy specific module
```

### State Management
```bash
terraform state list              # List resources in state
terraform state show <resource>   # Show resource details
terraform state pull              # Download state
terraform state rm <resource>     # Remove from state
```

### Outputs
```bash
terraform output                  # Show all outputs
terraform output <name>           # Show specific output
terraform output -json            # JSON format
```

### Formatting & Validation
```bash
terraform fmt                     # Format files
terraform fmt -recursive          # Format recursively
terraform validate                # Validate configuration
```

---

## 🔧 AWS CLI Commands

### EC2
```bash
# List instances
aws ec2 describe-instances --region us-east-1

# Check instance status
aws ec2 describe-instance-status --instance-ids i-xxxxx

# Stop/Start instances
aws ec2 stop-instances --instance-ids i-xxxxx
aws ec2 start-instances --instance-ids i-xxxxx
```

### RDS
```bash
# List databases
aws rds describe-db-instances --region us-east-1

# Check database status
aws rds describe-db-instances --db-instance-identifier mydb

# Create snapshot
aws rds create-db-snapshot --db-instance-identifier mydb --db-snapshot-identifier mydb-snapshot

# Promote read replica
aws rds promote-read-replica --db-instance-identifier replica-id
```

### Auto Scaling
```bash
# List ASGs
aws autoscaling describe-auto-scaling-groups --region us-east-1

# Set desired capacity
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name my-asg \
  --desired-capacity 2

# Update ASG
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name my-asg \
  --min-size 1 --max-size 4
```

### Load Balancer
```bash
# List load balancers
aws elbv2 describe-load-balancers --region us-east-1

# Check target health
aws elbv2 describe-target-health --target-group-arn arn:xxx

# Describe listeners
aws elbv2 describe-listeners --load-balancer-arn arn:xxx
```

### S3
```bash
# List buckets
aws s3 ls

# List bucket contents
aws s3 ls s3://bucket-name

# Copy files
aws s3 cp file.txt s3://bucket-name/
aws s3 cp s3://bucket-name/file.txt ./

# Sync directories
aws s3 sync ./local-dir s3://bucket-name/
```

### Secrets Manager
```bash
# Get secret value
aws secretsmanager get-secret-value --secret-id my-secret

# Get database password
aws secretsmanager get-secret-value \
  --secret-id rds-password \
  --query SecretString --output text | jq -r .password
```

### CloudWatch
```bash
# List alarms
aws cloudwatch describe-alarms --region us-east-1

# Get alarm history
aws cloudwatch describe-alarm-history --alarm-name my-alarm

# Get metric statistics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=i-xxxxx \
  --start-time 2025-12-11T00:00:00Z \
  --end-time 2025-12-11T23:59:59Z \
  --period 3600 \
  --statistics Average
```

---

## 🔄 Disaster Recovery Commands

### Failover to Secondary
```bash
# 1. Scale up secondary region
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name secondary-web-asg \
  --desired-capacity 2 --region us-west-2

aws autoscaling set-desired-capacity \
  --auto-scaling-group-name secondary-app-asg \
  --desired-capacity 2 --region us-west-2

# 2. Promote read replica
aws rds promote-read-replica \
  --db-instance-identifier secondary-db \
  --region us-west-2

# 3. Monitor promotion
aws rds describe-db-instances \
  --db-instance-identifier secondary-db \
  --region us-west-2 \
  --query 'DBInstances[0].DBInstanceStatus'

# 4. Update DNS (manual or via Route 53)
```

### Failback to Primary
```bash
# 1. Verify primary is healthy
cd environments/primary && terraform plan

# 2. Create snapshot from secondary
aws rds create-db-snapshot \
  --db-instance-identifier secondary-db \
  --db-snapshot-identifier failback-snapshot \
  --region us-west-2

# 3. Restore primary from snapshot
# (See RUNBOOK.md for detailed steps)

# 4. Scale down secondary
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name secondary-web-asg \
  --desired-capacity 1 --region us-west-2
```

---

## 📊 Monitoring Commands

### Check Infrastructure Health
```bash
# Primary region health
aws elbv2 describe-target-health \
  --target-group-arn <PRIMARY_TG_ARN> \
  --region us-east-1

# Secondary region health
aws elbv2 describe-target-health \
  --target-group-arn <SECONDARY_TG_ARN> \
  --region us-west-2

# RDS replication lag
aws rds describe-db-instances \
  --db-instance-identifier secondary-db \
  --region us-west-2 \
  --query 'DBInstances[0].StatusInfos'
```

### View Logs
```bash
# CloudWatch Logs
aws logs tail /aws/ec2/web/nginx-access --follow --region us-east-1

# VPC Flow Logs
aws logs tail /aws/vpc/flow-logs --follow --region us-east-1

# RDS Logs
aws rds describe-db-log-files \
  --db-instance-identifier mydb \
  --region us-east-1
```

---

## 🔍 Troubleshooting Commands

### Debug EC2 Issues
```bash
# Check instance logs
aws ec2 get-console-output --instance-id i-xxxxx

# Check system status
aws ec2 describe-instance-status --instance-ids i-xxxxx

# Check security groups
aws ec2 describe-security-groups --group-ids sg-xxxxx
```

### Debug RDS Issues
```bash
# Check RDS events
aws rds describe-events \
  --source-identifier mydb \
  --source-type db-instance

# Check parameter group
aws rds describe-db-parameters \
  --db-parameter-group-name mydb-params

# Check option group
aws rds describe-option-groups \
  --option-group-name mydb-options
```

### Debug Network Issues
```bash
# Check VPC
aws ec2 describe-vpcs --vpc-ids vpc-xxxxx

# Check subnets
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-xxxxx"

# Check route tables
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=vpc-xxxxx"

# Check NAT gateways
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=vpc-xxxxx"

# Check VPC Flow Logs
aws ec2 describe-flow-logs --filter "Name=resource-id,Values=vpc-xxxxx"
```

---

## 📁 Important File Locations

### Configuration Files
```
environments/primary/terraform.tfvars       # Primary config
environments/secondary/terraform.tfvars     # Secondary config
global/s3-backend/terraform.tfstate         # Backend state
```

### State Files
```
s3://BUCKET/primary/terraform.tfstate       # Primary state
s3://BUCKET/secondary/terraform.tfstate     # Secondary state
s3://BUCKET/global/iam/terraform.tfstate    # IAM state
```

### Logs
```
/var/log/nginx/access.log                   # Nginx access
/var/log/nginx/error.log                    # Nginx errors
CloudWatch: /aws/ec2/web/nginx-access       # Web logs
CloudWatch: /aws/ec2/app/system             # App logs
CloudWatch: /aws/vpc/flow-logs              # VPC logs
```

---

## 🔐 Security Commands

### Check Encryption
```bash
# RDS encryption
aws rds describe-db-instances \
  --query 'DBInstances[*].[DBInstanceIdentifier,StorageEncrypted]'

# S3 encryption
aws s3api get-bucket-encryption --bucket my-bucket

# EBS encryption
aws ec2 describe-volumes \
  --query 'Volumes[*].[VolumeId,Encrypted]'
```

### Rotate Credentials
```bash
# Rotate RDS password
aws rds modify-db-instance \
  --db-instance-identifier mydb \
  --master-user-password NewPassword123! \
  --apply-immediately

# Update secret
aws secretsmanager update-secret \
  --secret-id my-secret \
  --secret-string '{"password":"NewPassword123!"}'
```

---

## 💰 Cost Management

### Check Costs
```bash
# Get cost and usage
aws ce get-cost-and-usage \
  --time-period Start=2025-12-01,End=2025-12-31 \
  --granularity MONTHLY \
  --metrics "UnblendedCost" \
  --group-by Type=SERVICE

# Get cost forecast
aws ce get-cost-forecast \
  --time-period Start=2025-12-11,End=2025-12-31 \
  --metric UNBLENDED_COST \
  --granularity MONTHLY
```

### Optimize Costs
```bash
# Stop non-production instances
aws ec2 stop-instances --instance-ids i-xxxxx

# Reduce ASG capacity
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name my-asg \
  --desired-capacity 1

# Delete old snapshots
aws rds delete-db-snapshot --db-snapshot-identifier old-snapshot
```

---

## 📞 Quick Links

- **Documentation**: `docs/`
- **Modules**: `modules/`
- **Scripts**: `scripts/`
- **GitHub**: https://github.com/TechFxSolutions/terraform-aws-dr-infrastructure
- **Issues**: https://github.com/TechFxSolutions/terraform-aws-dr-infrastructure/issues

---

## 🆘 Emergency Contacts

### Incident Response
1. Check RUNBOOK.md for procedures
2. Run validation script
3. Check CloudWatch alarms
4. Review recent changes
5. Escalate if needed

### Support Channels
- GitHub Issues (non-urgent)
- Email: support@example.com (urgent)
- On-call: See RUNBOOK.md

---

**Last Updated**: December 11, 2025
