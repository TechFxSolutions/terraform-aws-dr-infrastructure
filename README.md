# Terraform AWS Disaster Recovery Infrastructure

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Terraform](https://img.shields.io/badge/Terraform-1.6+-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Free_Tier-FF9900?logo=amazon-aws)](https://aws.amazon.com/free/)
[![SOC-2](https://img.shields.io/badge/Compliance-SOC--2-green)](https://www.aicpa.org/soc)

Production-ready, SOC-2 compliant Terraform infrastructure-as-code solution for deploying a three-tier web application on AWS with active-passive disaster recovery architecture.

## 🎯 Project Overview

This project provides enterprise-grade infrastructure automation for:

- **Three-Tier Architecture**: Web, Application, and Database layers
- **Active-Passive DR**: Multi-region disaster recovery setup
- **SOC-2 Compliance**: Security controls and audit logging
- **AWS Free Tier**: Cost-optimized for free-tier resources
- **Production Ready**: Following HashiCorp and AWS best practices

## 🏗️ Architecture

```
Primary Region (Active)          Secondary Region (Passive)
┌─────────────────────┐         ┌─────────────────────┐
│   Route 53 (DNS)    │◄────────┤  Health Checks      │
└──────────┬──────────┘         └─────────────────────┘
           │
    ┌──────▼──────┐              ┌─────────────────┐
    │     ALB     │              │      ALB        │
    └──────┬──────┘              └─────────────────┘
           │
    ┌──────▼──────┐              ┌─────────────────┐
    │  Web Tier   │              │   Web Tier      │
    │ (EC2 t2.micro)│            │  (EC2 t2.micro) │
    └──────┬──────┘              └─────────────────┘
           │
    ┌──────▼──────┐              ┌─────────────────┐
    │  App Tier   │              │   App Tier      │
    │ (EC2 t2.micro)│            │  (EC2 t2.micro) │
    └──────┬──────┘              └─────────────────┘
           │
    ┌──────▼──────┐              ┌─────────────────┐
    │  Data Tier  │◄─────────────┤   Data Tier     │
    │ (RDS t2.micro)│  Replication│  (RDS t2.micro) │
    └─────────────┘              └─────────────────┘
```

## 📋 Prerequisites

- **Terraform**: >= 1.6.0
- **AWS Account**: With appropriate permissions
- **AWS CLI**: >= 2.0
- **Git**: For version control
- **GitHub Account**: For repository access

## 🚀 Quick Start (Recommended)

### Option A: Automated Deployment with .env File (Easiest)

```bash
# 1. Clone repository
git clone https://github.com/TechFxSolutions/terraform-aws-dr-infrastructure.git
cd terraform-aws-dr-infrastructure

# 2. Setup AWS credentials in .env file
cp .env.example .env
nano .env  # Add your AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY

# 3. Configure Terraform variables
cp environments/primary/terraform.tfvars.example environments/primary/terraform.tfvars
cp environments/secondary/terraform.tfvars.example environments/secondary/terraform.tfvars
# Edit both files with your settings

# 4. Make scripts executable
chmod +x scripts/*.sh

# 5. Deploy everything!
./scripts/deploy-all.sh
```

**Deployment Time**: 30-40 minutes  
**See**: [Quick Start with .env Guide](docs/QUICK_START_WITH_ENV.md) for detailed instructions

### Option B: Manual Step-by-Step Deployment

#### 1. Clone Repository

```bash
git clone https://github.com/TechFxSolutions/terraform-aws-dr-infrastructure.git
cd terraform-aws-dr-infrastructure
```

#### 2. Configure AWS Credentials

**Method 1: Using .env file (Recommended)**

```bash
cp .env.example .env
nano .env  # Add your credentials
```

See [.env File Setup Guide](docs/ENV_FILE_SETUP.md) for detailed instructions.

**Method 2: Using AWS CLI**

```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, and region
```

See [AWS Credentials Setup Guide](docs/AWS_CREDENTIALS_SETUP.md) for more options.

#### 3. Initialize Terraform Backend

```bash
cd global/s3-backend
terraform init
terraform apply
```

#### 4. Deploy Primary Region

```bash
cd ../../environments/primary
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Configure your settings

terraform init
terraform plan
terraform apply
```

#### 5. Deploy Secondary Region

```bash
cd ../secondary
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Configure your settings

terraform init
terraform plan
terraform apply
```

## 🔧 Common Issues & Fixes

### Permission Denied on Scripts

If you get `Permission denied` when running scripts:

```bash
# Fix: Make scripts executable
chmod +x scripts/*.sh

# Or run the helper script
bash scripts/make-executable.sh

# Then run your script
./scripts/deploy-all.sh
```

### AWS Credentials Not Found

```bash
# Option 1: Load .env file manually
source .env

# Option 2: Configure AWS CLI
aws configure

# Verify credentials work
aws sts get-caller-identity
```

## 📁 Project Structure

```
terraform-aws-dr-infrastructure/
├── .github/
│   └── workflows/              # CI/CD pipelines
├── modules/
│   ├── networking/             # VPC, subnets, route tables
│   ├── compute/                # EC2 instances, ASG
│   ├── database/               # RDS configuration
│   ├── security/               # Security groups, IAM
│   ├── monitoring/             # CloudWatch, alarms
│   └── storage/                # S3, EBS
├── environments/
│   ├── primary/                # Primary region config
│   └── secondary/              # Secondary region config
├── global/
│   ├── iam/                    # Global IAM resources
│   └── s3-backend/             # Terraform state backend
├── scripts/
│   ├── deploy-all.sh           # Automated deployment
│   ├── validate-deployment.sh  # Validation script
│   ├── destroy-all.sh          # Cleanup script
│   └── make-executable.sh      # Fix permissions
├── docs/                       # Documentation
├── .env.example                # AWS credentials template
├── .gitignore
├── README.md
├── LICENSE
└── CHANGELOG.md
```

## 🔒 Security & Compliance

This infrastructure implements SOC-2 compliance controls:

- ✅ **Access Control**: IAM roles with least-privilege
- ✅ **Encryption**: At-rest and in-transit encryption
- ✅ **Logging**: CloudTrail and CloudWatch Logs
- ✅ **Monitoring**: Real-time alerts and dashboards
- ✅ **Network Security**: VPC isolation, security groups
- ✅ **Audit Trail**: Complete audit logging
- ✅ **Backup & Recovery**: Automated backups

See [SOC-2 Compliance Documentation](docs/SOC2_COMPLIANCE.md) for details.

## 💰 Cost Optimization

Designed to run within AWS Free Tier limits:

- **EC2**: t2.micro instances (750 hours/month)
- **RDS**: db.t2.micro (750 hours/month)
- **Storage**: 30 GB EBS, 5 GB S3
- **Networking**: VPC, subnets (free)
- **Monitoring**: 10 CloudWatch metrics/alarms

**Estimated Monthly Cost**: 
- With Free Tier: $50-80/month
- Without Free Tier: $200-300/month

## 🔄 Disaster Recovery

### Failover Process

1. **Automated Health Checks**: Route 53 monitors primary region
2. **DNS Failover**: Automatic traffic routing to secondary
3. **Data Replication**: Continuous cross-region replication
4. **Manual Failover**: Documented procedures available

**RTO (Recovery Time Objective)**: < 15 minutes  
**RPO (Recovery Point Objective)**: < 5 minutes

See [DR Runbook](docs/RUNBOOK.md) for detailed procedures.

## 🛠️ Useful Commands

### Deployment

```bash
# Deploy all infrastructure
./scripts/deploy-all.sh

# Validate deployment
./scripts/validate-deployment.sh

# Destroy all infrastructure
./scripts/destroy-all.sh
```

### Terraform Commands

```bash
# Format code
terraform fmt -recursive

# Validate configuration
terraform validate

# Plan changes
terraform plan

# Apply changes
terraform apply

# Show outputs
terraform output
```

### AWS Commands

```bash
# Verify credentials
aws sts get-caller-identity

# List EC2 instances
aws ec2 describe-instances --region us-east-1

# Check RDS status
aws rds describe-db-instances --region us-east-1
```

## 📚 Documentation

### Getting Started
- [Quick Start with .env](docs/QUICK_START_WITH_ENV.md) - Fastest way to get started
- [.env File Setup Guide](docs/ENV_FILE_SETUP.md) - Detailed .env configuration
- [AWS Credentials Setup](docs/AWS_CREDENTIALS_SETUP.md) - Alternative credential methods
- [Deployment Guide](docs/DEPLOYMENT.md) - Step-by-step deployment

### Architecture & Operations
- [Architecture Guide](docs/ARCHITECTURE.md) - Detailed architecture
- [DR Runbook](docs/RUNBOOK.md) - Disaster recovery procedures
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions
- [Quick Reference](QUICK_REFERENCE.md) - Command reference

### Compliance & Development
- [SOC-2 Compliance](docs/SOC2_COMPLIANCE.md) - Compliance documentation
- [Contributing Guide](CONTRIBUTING.md) - How to contribute
- [Project Summary](PROJECT_SUMMARY.md) - Complete project overview

## 🧪 Testing

```bash
# Format check
terraform fmt -check -recursive

# Validation
terraform validate

# Security scan
tfsec .
checkov -d .

# Cost estimation
infracost breakdown --path .
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

See [Contributing Guide](CONTRIBUTING.md) for detailed guidelines.

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [HashiCorp Terraform](https://www.terraform.io/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

## 📞 Support

For issues and questions:
- Open an [Issue](https://github.com/TechFxSolutions/terraform-aws-dr-infrastructure/issues)
- Check [Documentation](docs/)
- Review [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
- See [Quick Reference](QUICK_REFERENCE.md)

## 🎯 Next Steps After Deployment

1. **Verify Deployment**: Run `./scripts/validate-deployment.sh`
2. **Access Application**: Check outputs for ALB DNS name
3. **Configure DNS**: Point your domain to the ALB
4. **Deploy Application**: SSH to instances or use CI/CD
5. **Test Failover**: Follow the DR Runbook
6. **Set Up Monitoring**: Configure CloudWatch alarms
7. **Review Security**: Check SOC-2 compliance documentation

---

**Built with ❤️ for enterprise-grade infrastructure automation**

*Last Updated: December 11, 2025*
