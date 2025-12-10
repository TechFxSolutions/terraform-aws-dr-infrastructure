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

## 🚀 Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/TechFxSolutions/terraform-aws-dr-infrastructure.git
cd terraform-aws-dr-infrastructure
```

### 2. Configure AWS Credentials

See [AWS Credentials Setup Guide](docs/AWS_CREDENTIALS_SETUP.md) for detailed instructions.

```bash
# Configure AWS CLI
aws configure

# Verify credentials
aws sts get-caller-identity
```

### 3. Initialize Terraform Backend

```bash
cd global/s3-backend
terraform init
terraform apply
```

### 4. Deploy Primary Region

```bash
cd ../../environments/primary
terraform init
terraform plan
terraform apply
```

### 5. Deploy Secondary Region

```bash
cd ../secondary
terraform init
terraform plan
terraform apply
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
│   ├── route53/                # DNS configuration
│   └── s3-backend/             # Terraform state backend
├── scripts/                    # Helper scripts
├── docs/                       # Documentation
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

**Estimated Monthly Cost**: $0 (within free tier limits)

## 🔄 Disaster Recovery

### Failover Process

1. **Automated Health Checks**: Route 53 monitors primary region
2. **DNS Failover**: Automatic traffic routing to secondary
3. **Data Replication**: Continuous cross-region replication
4. **Manual Failover**: Documented procedures available

**RTO (Recovery Time Objective)**: < 15 minutes  
**RPO (Recovery Point Objective)**: < 5 minutes

See [DR Runbook](docs/RUNBOOK.md) for detailed procedures.

## 🛠️ Development Workflow

### Branching Strategy

- `main` - Production-ready code
- `develop` - Integration branch
- `feature/*` - Feature development
- `hotfix/*` - Emergency fixes
- `release/*` - Release preparation

### Making Changes

```bash
# Create feature branch
git checkout -b feature/your-feature-name

# Make changes and commit
git add .
git commit -m "feat: your feature description"

# Push and create PR
git push origin feature/your-feature-name
```

## 📚 Documentation

- [Architecture Guide](docs/ARCHITECTURE.md)
- [Deployment Guide](docs/DEPLOYMENT.md)
- [AWS Credentials Setup](docs/AWS_CREDENTIALS_SETUP.md)
- [SOC-2 Compliance](docs/SOC2_COMPLIANCE.md)
- [DR Runbook](docs/RUNBOOK.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

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

---

**Built with ❤️ for enterprise-grade infrastructure automation**
