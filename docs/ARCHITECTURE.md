# Architecture Documentation

## Overview

This document describes the architecture of the AWS Disaster Recovery infrastructure for a three-tier web application using an active-passive failover strategy.

## Architecture Principles

### Design Goals
- **High Availability**: 99.9% uptime SLA
- **Disaster Recovery**: RTO < 15 minutes, RPO < 5 minutes
- **Security**: SOC-2 compliant controls
- **Cost Optimization**: AWS Free Tier compatible
- **Scalability**: Auto-scaling capabilities
- **Maintainability**: Infrastructure as Code

### Architecture Patterns
- **Three-Tier Architecture**: Separation of concerns
- **Active-Passive DR**: Cost-effective disaster recovery
- **Multi-Region**: Geographic redundancy
- **Infrastructure as Code**: Terraform automation

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Route 53 (Global DNS)                    │
│                  Health Checks & Failover                    │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
        ▼                         ▼
┌───────────────┐         ┌───────────────┐
│ Primary Region│         │Secondary Region│
│  (us-east-1)  │         │  (us-west-2)   │
│    ACTIVE     │         │    PASSIVE     │
└───────────────┘         └───────────────┘
```

## Regional Architecture

### Primary Region (Active)

```
┌─────────────────────────────────────────────────────────┐
│                    VPC (10.0.0.0/16)                     │
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │         Availability Zone 1 & 2                 │    │
│  │                                                 │    │
│  │  ┌──────────────────────────────────────┐     │    │
│  │  │      Public Subnets                   │     │    │
│  │  │  ┌─────────────────────────────┐     │     │    │
│  │  │  │  Application Load Balancer   │     │     │    │
│  │  │  └──────────┬──────────────────┘     │     │    │
│  │  └─────────────┼────────────────────────┘     │    │
│  │                │                               │    │
│  │  ┌─────────────▼────────────────────────┐     │    │
│  │  │      Private Subnets (Web Tier)      │     │    │
│  │  │  ┌────────────┐    ┌────────────┐   │     │    │
│  │  │  │ EC2 Web 1  │    │ EC2 Web 2  │   │     │    │
│  │  │  │ (t2.micro) │    │ (t2.micro) │   │     │    │
│  │  │  └─────┬──────┘    └──────┬─────┘   │     │    │
│  │  └────────┼──────────────────┼──────────┘     │    │
│  │           │                  │                │    │
│  │  ┌────────▼──────────────────▼──────────┐     │    │
│  │  │   Private Subnets (App Tier)         │     │    │
│  │  │  ┌────────────┐    ┌────────────┐   │     │    │
│  │  │  │ EC2 App 1  │    │ EC2 App 2  │   │     │    │
│  │  │  │ (t2.micro) │    │ (t2.micro) │   │     │    │
│  │  │  └─────┬──────┘    └──────┬─────┘   │     │    │
│  │  └────────┼──────────────────┼──────────┘     │    │
│  │           │                  │                │    │
│  │  ┌────────▼──────────────────▼──────────┐     │    │
│  │  │   Private Subnets (Data Tier)        │     │    │
│  │  │  ┌──────────────────────────────┐   │     │    │
│  │  │  │   RDS Multi-AZ (Primary)     │   │     │    │
│  │  │  │      db.t2.micro             │   │     │    │
│  │  │  │   PostgreSQL/MySQL           │   │     │    │
│  │  │  └──────────────────────────────┘   │     │    │
│  │  └───────────────────────────────────────┘     │    │
│  └─────────────────────────────────────────────────┘    │
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │         Security & Monitoring                   │    │
│  │  • Security Groups                              │    │
│  │  • Network ACLs                                 │    │
│  │  • VPC Flow Logs                                │    │
│  │  • CloudWatch Metrics & Alarms                  │    │
│  │  • CloudTrail Logging                           │    │
│  └────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

### Secondary Region (Passive)

Identical architecture to primary region, but in standby mode:
- EC2 instances can be stopped or running at minimal capacity
- RDS read replica for data replication
- Load balancer configured but not receiving traffic
- All security and monitoring in place

## Component Details

### 1. Network Layer

#### VPC Configuration
- **CIDR Block**: 10.0.0.0/16 (Primary), 10.1.0.0/16 (Secondary)
- **Subnets**: 
  - Public: 10.0.1.0/24, 10.0.2.0/24 (AZ1, AZ2)
  - Private Web: 10.0.11.0/24, 10.0.12.0/24
  - Private App: 10.0.21.0/24, 10.0.22.0/24
  - Private Data: 10.0.31.0/24, 10.0.32.0/24

#### Internet Connectivity
- **Internet Gateway**: Public subnet access
- **NAT Gateway**: Private subnet outbound access
- **VPC Peering**: Cross-region connectivity (optional)

#### Security
- **Security Groups**: Stateful firewall rules
- **Network ACLs**: Stateless subnet-level rules
- **VPC Flow Logs**: Network traffic logging

### 2. Compute Layer

#### Web Tier
- **Instance Type**: t2.micro (1 vCPU, 1 GB RAM)
- **Count**: 2 instances per region (Multi-AZ)
- **OS**: Amazon Linux 2023
- **Software**: Nginx/Apache web server
- **Auto Scaling**: Min: 2, Max: 4, Desired: 2

#### Application Tier
- **Instance Type**: t2.micro
- **Count**: 2 instances per region (Multi-AZ)
- **OS**: Amazon Linux 2023
- **Software**: Application runtime (Node.js/Python/Java)
- **Auto Scaling**: Min: 2, Max: 4, Desired: 2

#### Load Balancing
- **Type**: Application Load Balancer (ALB)
- **Scheme**: Internet-facing
- **Health Checks**: HTTP/HTTPS endpoints
- **Listeners**: HTTP (80), HTTPS (443)

### 3. Database Layer

#### RDS Configuration
- **Engine**: PostgreSQL 15 or MySQL 8.0
- **Instance Class**: db.t2.micro (1 vCPU, 1 GB RAM)
- **Storage**: 20 GB General Purpose SSD (gp2)
- **Multi-AZ**: Enabled in primary region
- **Backup**: Automated daily backups (7-day retention)

#### Replication
- **Primary Region**: Master database
- **Secondary Region**: Read replica
- **Replication Lag**: < 5 minutes
- **Promotion**: Manual or automated failover

### 4. Storage Layer

#### S3 Buckets
- **Application Assets**: Static files, media
- **Backups**: Database and application backups
- **Logs**: Application and access logs
- **Terraform State**: Remote state storage

#### S3 Configuration
- **Versioning**: Enabled
- **Encryption**: AES-256 (SSE-S3)
- **Lifecycle Policies**: Transition to Glacier after 90 days
- **Cross-Region Replication**: Primary → Secondary

### 5. DNS & Traffic Management

#### Route 53
- **Hosted Zone**: Public DNS zone
- **Health Checks**: Primary region endpoint monitoring
- **Routing Policy**: Failover routing
- **TTL**: 60 seconds for fast failover

#### Failover Configuration
```
Primary Record (Active):
  - Type: A (Alias to ALB)
  - Routing: Failover Primary
  - Health Check: Enabled

Secondary Record (Passive):
  - Type: A (Alias to ALB)
  - Routing: Failover Secondary
  - Health Check: Enabled
```

## Security Architecture

### Identity & Access Management

#### IAM Roles
- **EC2 Instance Role**: CloudWatch, S3, Secrets Manager access
- **RDS Enhanced Monitoring Role**: Performance insights
- **Lambda Execution Role**: Automation functions
- **Terraform Role**: Infrastructure provisioning

#### IAM Policies
- Least-privilege access
- Service-specific policies
- Resource-level permissions
- Condition-based access

### Network Security

#### Security Group Rules

**ALB Security Group**
```
Inbound:
  - HTTP (80) from 0.0.0.0/0
  - HTTPS (443) from 0.0.0.0/0
Outbound:
  - All traffic to Web Tier SG
```

**Web Tier Security Group**
```
Inbound:
  - HTTP (80) from ALB SG
  - HTTPS (443) from ALB SG
  - SSH (22) from Bastion SG
Outbound:
  - All traffic to App Tier SG
```

**App Tier Security Group**
```
Inbound:
  - App Port (8080) from Web Tier SG
  - SSH (22) from Bastion SG
Outbound:
  - PostgreSQL (5432) to Data Tier SG
  - HTTPS (443) to 0.0.0.0/0
```

**Data Tier Security Group**
```
Inbound:
  - PostgreSQL (5432) from App Tier SG
Outbound:
  - None (default deny)
```

### Data Protection

#### Encryption at Rest
- **EBS Volumes**: AWS KMS encryption
- **RDS**: AWS KMS encryption
- **S3 Buckets**: SSE-S3 or SSE-KMS
- **Secrets Manager**: KMS encryption

#### Encryption in Transit
- **HTTPS/TLS**: All external communication
- **SSL/TLS**: Database connections
- **VPN**: Cross-region replication

### Monitoring & Logging

#### CloudWatch
- **Metrics**: CPU, memory, disk, network
- **Alarms**: Threshold-based alerts
- **Dashboards**: Real-time monitoring
- **Logs**: Application and system logs

#### CloudTrail
- **API Logging**: All AWS API calls
- **Multi-Region**: Enabled
- **Log File Validation**: Enabled
- **S3 Storage**: Encrypted and versioned

#### VPC Flow Logs
- **Traffic Monitoring**: All network traffic
- **Storage**: CloudWatch Logs or S3
- **Retention**: 90 days

## Disaster Recovery Strategy

### Active-Passive Architecture

#### Normal Operations (Active)
- Primary region handles all traffic
- Secondary region in standby mode
- Continuous data replication
- Regular health checks

#### Failover Scenario (Passive → Active)
1. **Detection**: Route 53 health check fails
2. **DNS Update**: Traffic routed to secondary region
3. **Database Promotion**: Read replica promoted to master
4. **Application Start**: EC2 instances scaled up
5. **Verification**: Health checks confirm availability

### Recovery Objectives

- **RTO (Recovery Time Objective)**: < 15 minutes
- **RPO (Recovery Point Objective)**: < 5 minutes
- **Availability Target**: 99.9% uptime

### Backup Strategy

#### Database Backups
- **Automated Backups**: Daily snapshots
- **Retention**: 7 days
- **Cross-Region Copy**: Enabled
- **Point-in-Time Recovery**: Enabled

#### Application Backups
- **AMI Snapshots**: Weekly
- **Configuration Backups**: Daily to S3
- **Code Repository**: GitHub

## Scalability

### Horizontal Scaling
- **Auto Scaling Groups**: Dynamic capacity
- **Load Balancing**: Traffic distribution
- **Database Read Replicas**: Read scaling

### Vertical Scaling
- **Instance Resizing**: Upgrade instance types
- **RDS Scaling**: Increase storage and compute
- **EBS Volume Expansion**: Increase storage

## Cost Optimization

### Free Tier Usage
- **EC2**: 750 hours/month (t2.micro)
- **RDS**: 750 hours/month (db.t2.micro)
- **EBS**: 30 GB General Purpose SSD
- **S3**: 5 GB Standard Storage
- **Data Transfer**: 1 GB/month outbound

### Cost Monitoring
- **AWS Cost Explorer**: Usage tracking
- **Budgets**: Cost alerts
- **Resource Tagging**: Cost allocation

## Compliance

### SOC-2 Controls
- **Access Control**: IAM, MFA
- **Encryption**: At-rest and in-transit
- **Logging**: CloudTrail, CloudWatch
- **Monitoring**: Real-time alerts
- **Backup**: Automated backups
- **Audit**: Compliance reports

## Future Enhancements

### Phase 2 Improvements
- [ ] Multi-region active-active architecture
- [ ] Container orchestration (ECS/EKS)
- [ ] Serverless components (Lambda)
- [ ] Advanced monitoring (X-Ray, Prometheus)
- [ ] CI/CD pipeline integration
- [ ] Infrastructure testing (Terratest)

### Scalability Enhancements
- [ ] CDN integration (CloudFront)
- [ ] Caching layer (ElastiCache)
- [ ] Message queuing (SQS)
- [ ] Microservices architecture

## References

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [AWS Disaster Recovery](https://aws.amazon.com/disaster-recovery/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [SOC 2 Compliance](https://www.aicpa.org/soc)

---

**Next**: [Deployment Guide](DEPLOYMENT.md)
