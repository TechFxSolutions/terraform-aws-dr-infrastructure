# Disaster Recovery Runbook

Operational procedures for disaster recovery scenarios and failover operations.

## Overview

This runbook provides step-by-step procedures for:
- Monitoring system health
- Detecting failures
- Executing failover procedures
- Performing failback operations
- Testing DR capabilities

## Recovery Objectives

- **RTO (Recovery Time Objective)**: < 15 minutes
- **RPO (Recovery Point Objective)**: < 5 minutes
- **Availability Target**: 99.9% uptime

## Roles and Responsibilities

### Incident Commander
- Overall incident coordination
- Communication with stakeholders
- Decision authority for failover

### Technical Lead
- Execute technical procedures
- Monitor system status
- Coordinate with team members

### Communications Lead
- Stakeholder notifications
- Status updates
- Post-incident reporting

## Monitoring and Detection

### Health Check Monitoring

#### Route 53 Health Checks
```bash
# Check health check status
aws route53 get-health-check-status \
  --health-check-id <HEALTH_CHECK_ID>

# List all health checks
aws route53 list-health-checks
```

#### CloudWatch Alarms
```bash
# Check alarm status
aws cloudwatch describe-alarms \
  --region us-east-1 \
  --state-value ALARM

# Get alarm history
aws cloudwatch describe-alarm-history \
  --alarm-name <ALARM_NAME> \
  --max-records 10
```

### Key Metrics to Monitor

#### Application Tier
- **CPU Utilization**: < 80%
- **Memory Usage**: < 85%
- **Response Time**: < 500ms
- **Error Rate**: < 1%

#### Database Tier
- **CPU Utilization**: < 70%
- **Connections**: < 80% of max
- **Replication Lag**: < 5 seconds
- **Storage**: < 80% capacity

#### Network Tier
- **ALB Healthy Hosts**: >= 2
- **Target Response Time**: < 200ms
- **HTTP 5xx Errors**: < 0.1%
- **Network Throughput**: Within normal range

## Failure Scenarios

### Scenario 1: Primary Region Complete Outage

**Detection**:
- Route 53 health checks fail
- CloudWatch alarms trigger
- Application unavailable

**Impact**: Complete service disruption in primary region

**Procedure**: Execute full failover to secondary region

### Scenario 2: Database Failure

**Detection**:
- RDS instance status not "available"
- Connection errors
- Replication lag increasing

**Impact**: Data layer unavailable

**Procedure**: Promote read replica or restore from backup

### Scenario 3: Application Tier Failure

**Detection**:
- ALB health checks failing
- High error rates
- Auto-scaling not recovering

**Impact**: Application unavailable

**Procedure**: Restart instances or deploy to secondary region

### Scenario 4: Network Connectivity Issues

**Detection**:
- VPC Flow Logs show dropped packets
- Increased latency
- Intermittent connectivity

**Impact**: Degraded performance

**Procedure**: Investigate network path, check security groups

## Failover Procedures

### Pre-Failover Checklist

- [ ] Confirm primary region is truly unavailable
- [ ] Verify secondary region is healthy
- [ ] Notify stakeholders of impending failover
- [ ] Document current state
- [ ] Assemble incident response team

### Automated Failover (Route 53)

Route 53 health checks automatically failover DNS when primary region is unhealthy.

**Verification**:
```bash
# Check DNS resolution
dig +short YOUR_DOMAIN_NAME

# Should return secondary region ALB
# Primary: xxx.us-east-1.elb.amazonaws.com
# Secondary: xxx.us-west-2.elb.amazonaws.com
```

**Timeline**:
1. Health check fails (3 consecutive failures = ~90 seconds)
2. Route 53 updates DNS (immediate)
3. DNS propagation (TTL = 60 seconds)
4. **Total**: ~2-3 minutes

### Manual Failover Procedure

If automated failover doesn't occur or you need to force failover:

#### Step 1: Verify Secondary Region Status

```bash
# Check EC2 instances
aws ec2 describe-instances \
  --region us-west-2 \
  --filters "Name=tag:Environment,Values=secondary" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' \
  --output table

# Check RDS read replica
aws rds describe-db-instances \
  --region us-west-2 \
  --db-instance-identifier secondary-db \
  --query 'DBInstances[0].DBInstanceStatus'
```

#### Step 2: Scale Up Secondary Region

```bash
# Update Auto Scaling Group desired capacity
aws autoscaling set-desired-capacity \
  --region us-west-2 \
  --auto-scaling-group-name secondary-web-asg \
  --desired-capacity 2

aws autoscaling set-desired-capacity \
  --region us-west-2 \
  --auto-scaling-group-name secondary-app-asg \
  --desired-capacity 2

# Wait for instances to be healthy
aws autoscaling describe-auto-scaling-groups \
  --region us-west-2 \
  --auto-scaling-group-names secondary-web-asg secondary-app-asg \
  --query 'AutoScalingGroups[*].[AutoScalingGroupName,DesiredCapacity,Instances[*].HealthStatus]'
```

#### Step 3: Promote RDS Read Replica

```bash
# Promote read replica to standalone instance
aws rds promote-read-replica \
  --region us-west-2 \
  --db-instance-identifier secondary-db

# Monitor promotion progress
aws rds describe-db-instances \
  --region us-west-2 \
  --db-instance-identifier secondary-db \
  --query 'DBInstances[0].[DBInstanceStatus,ReadReplicaSourceDBInstanceIdentifier]'

# Wait for status to be "available" and ReadReplicaSourceDBInstanceIdentifier to be null
```

**Note**: Promotion takes 5-10 minutes

#### Step 4: Update DNS (Manual)

```bash
# Update Route 53 record to point to secondary ALB
aws route53 change-resource-record-sets \
  --hosted-zone-id <ZONE_ID> \
  --change-batch file://failover-dns-change.json
```

`failover-dns-change.json`:
```json
{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "app.example.com",
      "Type": "A",
      "AliasTarget": {
        "HostedZoneId": "<SECONDARY_ALB_ZONE_ID>",
        "DNSName": "<SECONDARY_ALB_DNS>",
        "EvaluateTargetHealth": true
      }
    }
  }]
}
```

#### Step 5: Verify Failover

```bash
# Test DNS resolution
dig +short app.example.com

# Test application endpoint
curl -I https://app.example.com

# Check ALB target health
aws elbv2 describe-target-health \
  --region us-west-2 \
  --target-group-arn <SECONDARY_TG_ARN>

# Verify database connectivity
psql -h <SECONDARY_RDS_ENDPOINT> -U dbadmin -d appdb -c "SELECT 1;"
```

#### Step 6: Monitor Secondary Region

```bash
# Watch CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --region us-west-2 \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=<ALB_NAME> \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# Check application logs
aws logs tail /aws/ec2/application --region us-west-2 --follow
```

### Failover Timeline

| Time | Action | Responsible |
|------|--------|-------------|
| T+0 | Incident detected | Monitoring System |
| T+2 | Incident confirmed | Technical Lead |
| T+3 | Stakeholders notified | Communications Lead |
| T+5 | Failover decision made | Incident Commander |
| T+6 | Scale up secondary region | Technical Lead |
| T+10 | Promote RDS replica | Technical Lead |
| T+12 | Update DNS | Technical Lead |
| T+15 | Verify failover complete | Technical Lead |
| T+20 | Confirm service restored | Incident Commander |

## Failback Procedures

After primary region is restored, failback to primary region.

### Pre-Failback Checklist

- [ ] Primary region fully operational
- [ ] Root cause identified and resolved
- [ ] All systems tested in primary region
- [ ] Maintenance window scheduled
- [ ] Stakeholders notified

### Failback Steps

#### Step 1: Restore Primary Region

```bash
# Verify primary region infrastructure
cd environments/primary
terraform plan
terraform apply

# Check all resources are healthy
aws ec2 describe-instances --region us-east-1 --filters "Name=tag:Environment,Values=primary"
aws rds describe-db-instances --region us-east-1
aws elbv2 describe-load-balancers --region us-east-1
```

#### Step 2: Sync Data from Secondary to Primary

```bash
# Create RDS snapshot from secondary (now primary)
aws rds create-db-snapshot \
  --region us-west-2 \
  --db-instance-identifier secondary-db \
  --db-snapshot-identifier failback-snapshot-$(date +%Y%m%d-%H%M%S)

# Copy snapshot to primary region
aws rds copy-db-snapshot \
  --region us-east-1 \
  --source-db-snapshot-identifier arn:aws:rds:us-west-2:ACCOUNT:snapshot:failback-snapshot-XXX \
  --target-db-snapshot-identifier failback-snapshot-XXX

# Restore primary database from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --region us-east-1 \
  --db-instance-identifier primary-db \
  --db-snapshot-identifier failback-snapshot-XXX
```

#### Step 3: Re-establish Replication

```bash
# Create new read replica in secondary region
aws rds create-db-instance-read-replica \
  --region us-west-2 \
  --db-instance-identifier secondary-db \
  --source-db-instance-identifier arn:aws:rds:us-east-1:ACCOUNT:db:primary-db

# Monitor replication lag
aws rds describe-db-instances \
  --region us-west-2 \
  --db-instance-identifier secondary-db \
  --query 'DBInstances[0].StatusInfos'
```

#### Step 4: Update DNS Back to Primary

```bash
# Update Route 53 to point back to primary
aws route53 change-resource-record-sets \
  --hosted-zone-id <ZONE_ID> \
  --change-batch file://failback-dns-change.json

# Verify DNS propagation
dig +short app.example.com
```

#### Step 5: Scale Down Secondary Region

```bash
# Reduce secondary region to standby capacity
aws autoscaling set-desired-capacity \
  --region us-west-2 \
  --auto-scaling-group-name secondary-web-asg \
  --desired-capacity 1

aws autoscaling set-desired-capacity \
  --region us-west-2 \
  --auto-scaling-group-name secondary-app-asg \
  --desired-capacity 1
```

## DR Testing

### Quarterly DR Test Schedule

- **Q1**: Automated failover test
- **Q2**: Manual failover test
- **Q3**: Full failover and failback test
- **Q4**: Chaos engineering test

### DR Test Procedure

#### Test 1: Automated Failover (Non-Disruptive)

```bash
# Simulate primary region failure by disabling health check endpoint
# This triggers Route 53 automatic failover

# 1. SSH to primary web servers
ssh -i key.pem ec2-user@<PRIMARY_WEB_IP>

# 2. Temporarily disable health check endpoint
sudo systemctl stop nginx  # or apache2

# 3. Monitor Route 53 failover
watch -n 5 'dig +short app.example.com'

# 4. Verify traffic goes to secondary
curl -I https://app.example.com

# 5. Re-enable health check
sudo systemctl start nginx

# 6. Verify failback to primary
watch -n 5 'dig +short app.example.com'
```

#### Test 2: Manual Failover (Scheduled Maintenance)

Follow the manual failover procedure above during a scheduled maintenance window.

#### Test 3: Data Recovery

```bash
# Test RDS snapshot restore
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier test-restore \
  --db-snapshot-identifier <SNAPSHOT_ID>

# Verify data integrity
psql -h <TEST_RDS_ENDPOINT> -U dbadmin -d appdb -c "SELECT COUNT(*) FROM users;"

# Cleanup
aws rds delete-db-instance \
  --db-instance-identifier test-restore \
  --skip-final-snapshot
```

### DR Test Report Template

```markdown
# DR Test Report

**Date**: YYYY-MM-DD
**Test Type**: [Automated/Manual/Full]
**Conducted By**: [Name]

## Test Objectives
- [ ] Verify automated failover
- [ ] Verify manual failover procedures
- [ ] Test data recovery
- [ ] Validate RTO/RPO

## Test Results

### Failover Metrics
- **Detection Time**: X minutes
- **Failover Time**: X minutes
- **Total RTO**: X minutes
- **Data Loss (RPO)**: X minutes

### Issues Encountered
1. Issue description
2. Issue description

### Lessons Learned
1. Lesson learned
2. Lesson learned

## Action Items
- [ ] Update runbook
- [ ] Fix identified issues
- [ ] Schedule follow-up test

**Status**: [PASS/FAIL]
```

## Communication Templates

### Incident Notification

```
Subject: [INCIDENT] Primary Region Outage - Failover Initiated

Priority: HIGH

We are experiencing an outage in our primary AWS region (us-east-1).

Status: Failover to secondary region (us-west-2) in progress
Impact: Service disruption for approximately 15 minutes
ETA: Service restoration by [TIME]

We will provide updates every 15 minutes.

Incident Commander: [NAME]
```

### Service Restored Notification

```
Subject: [RESOLVED] Service Restored - Running on Secondary Region

The service has been restored and is now running on our secondary region (us-west-2).

Status: OPERATIONAL
Downtime: [X] minutes
Root Cause: Under investigation

We will conduct a post-incident review and share findings within 48 hours.

Thank you for your patience.
```

## Post-Incident Review

### Post-Incident Review Template

1. **Incident Summary**
   - What happened?
   - When did it happen?
   - How long did it last?

2. **Timeline**
   - Detection
   - Response
   - Resolution

3. **Root Cause Analysis**
   - What was the root cause?
   - Why did it happen?
   - What were contributing factors?

4. **Impact Assessment**
   - Users affected
   - Data loss
   - Financial impact

5. **Response Evaluation**
   - What went well?
   - What could be improved?
   - Were procedures followed?

6. **Action Items**
   - Preventive measures
   - Process improvements
   - Documentation updates

## Emergency Contacts

| Role | Name | Phone | Email |
|------|------|-------|-------|
| Incident Commander | TBD | TBD | TBD |
| Technical Lead | TBD | TBD | TBD |
| AWS Support | - | - | aws-support |
| On-Call Engineer | TBD | TBD | TBD |

## References

- [Architecture Documentation](ARCHITECTURE.md)
- [Deployment Guide](DEPLOYMENT.md)
- [SOC-2 Compliance](SOC2_COMPLIANCE.md)
- [AWS Disaster Recovery](https://aws.amazon.com/disaster-recovery/)

---

**Document Owner**: Infrastructure Team  
**Last Updated**: 2025-12-10  
**Next Review**: 2026-03-10
