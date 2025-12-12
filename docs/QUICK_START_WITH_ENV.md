# Quick Start with .env File

The fastest way to get started with AWS credentials using the `.env` file.

## 🚀 5-Minute Setup

### Step 1: Clone Repository

```bash
git clone https://github.com/TechFxSolutions/terraform-aws-dr-infrastructure.git
cd terraform-aws-dr-infrastructure
```

### Step 2: Setup AWS Credentials

```bash
# Copy the example .env file
cp .env.example .env

# Edit .env and add your AWS credentials
nano .env
```

Add your credentials:

```bash
AWS_ACCESS_KEY_ID=your_access_key_here
AWS_SECRET_ACCESS_KEY=your_secret_key_here
AWS_DEFAULT_REGION=us-east-1
ALARM_EMAIL=your-email@example.com
```

### Step 3: Configure Terraform Variables

```bash
# Primary region
cp environments/primary/terraform.tfvars.example environments/primary/terraform.tfvars
nano environments/primary/terraform.tfvars

# Secondary region
cp environments/secondary/terraform.tfvars.example environments/secondary/terraform.tfvars
nano environments/secondary/terraform.tfvars
```

### Step 4: Deploy Everything

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Deploy all infrastructure
./scripts/deploy-all.sh
```

**That's it!** The script will:
- Load AWS credentials from `.env`
- Deploy S3 backend
- Deploy global IAM resources
- Deploy primary region infrastructure
- Deploy secondary region infrastructure

### Step 5: Validate Deployment

```bash
./scripts/validate-deployment.sh
```

---

## 📝 What Gets Created

### Primary Region (us-east-1)
- VPC with public/private subnets
- Application Load Balancer
- Auto Scaling Groups (Web + App tiers)
- RDS PostgreSQL database (Multi-AZ)
- S3 buckets for logs and backups
- CloudWatch monitoring and alarms

### Secondary Region (us-west-2)
- VPC with public/private subnets
- Application Load Balancer (standby)
- Auto Scaling Groups (minimal capacity)
- RDS Read Replica
- S3 buckets with replication
- CloudWatch monitoring

---

## 💰 Estimated Costs

**With AWS Free Tier**: $50-80/month  
**Without Free Tier**: $200-300/month

---

## 🔒 Security Notes

1. **Never commit .env to Git** - It's already in `.gitignore`
2. **Set restrictive permissions**: `chmod 600 .env`
3. **Rotate credentials regularly**
4. **Use IAM roles in production**

---

## 📚 Next Steps

1. **Access your application**: Check the output for the ALB DNS name
2. **Configure DNS**: Point your domain to the ALB
3. **Deploy your app**: SSH to instances or use CI/CD
4. **Test failover**: Follow the [DR Runbook](RUNBOOK.md)
5. **Set up monitoring**: Configure CloudWatch alarms

---

## 🆘 Troubleshooting

### Issue: "AWS credentials not configured"

```bash
# Load .env manually
source .env

# Verify
aws sts get-caller-identity
```

### Issue: "Permission denied" on scripts

```bash
chmod +x scripts/*.sh
```

### Issue: Deployment fails

```bash
# Check logs
cat terraform.log

# Validate configuration
terraform validate

# See troubleshooting guide
cat docs/TROUBLESHOOTING.md
```

---

## 🔗 Useful Links

- [Complete .env Setup Guide](ENV_FILE_SETUP.md)
- [AWS Credentials Setup](AWS_CREDENTIALS_SETUP.md)
- [Deployment Guide](DEPLOYMENT.md)
- [Architecture Documentation](ARCHITECTURE.md)
- [DR Runbook](RUNBOOK.md)
- [Quick Reference](../QUICK_REFERENCE.md)

---

## 🎯 Summary

```bash
# Complete setup in 5 commands
git clone https://github.com/TechFxSolutions/terraform-aws-dr-infrastructure.git
cd terraform-aws-dr-infrastructure
cp .env.example .env && nano .env
cp environments/primary/terraform.tfvars.example environments/primary/terraform.tfvars
./scripts/deploy-all.sh
```

**Deployment Time**: 30-40 minutes  
**Result**: Production-ready DR infrastructure across 2 AWS regions!

---

**Last Updated**: December 11, 2025
