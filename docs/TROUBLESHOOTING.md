# Troubleshooting Guide

Common issues and their solutions for the AWS DR infrastructure.

## Table of Contents

- [Terraform Issues](#terraform-issues)
- [AWS Resource Issues](#aws-resource-issues)
- [Network Connectivity](#network-connectivity)
- [Database Issues](#database-issues)
- [Application Issues](#application-issues)
- [Monitoring and Logging](#monitoring-and-logging)
- [Security Issues](#security-issues)

## Terraform Issues

### Issue: State Lock Error

**Error Message**:
```
Error: Error locking state: Error acquiring the state lock
```

**Cause**: Another Terraform process is running or previous process didn't release lock

**Solution**:
```bash
# Check who has the lock
aws dynamodb get-item \
  --table-name terraform-state-lock \
  --key '{"LockID":{"S":"terraform-state-lock-id"}}'

# Force unlock (use with caution!)
terraform force-unlock <LOCK_ID>

# Verify no other Terraform processes are running
ps aux | grep terraform
```

**Prevention**:
- Always let Terraform complete
- Use CI/CD with proper locking
- Don't run multiple Terraform processes simultaneously

### Issue: Provider Configuration Error

**Error Message**:
```
Error: error configuring Terraform AWS Provider: no valid credential sources found
```

**Cause**: AWS credentials not configured

**Solution**:
```bash
# Configure AWS CLI
aws configure

# Verify credentials
aws sts get-caller-identity

# Check environment variables
echo $AWS_ACCESS_KEY_ID
echo $AWS_SECRET_ACCESS_KEY
echo $AWS_DEFAULT_REGION

# Check credentials file
cat ~/.aws/credentials
```

### Issue: Resource Already Exists

**Error Message**:
```
Error: Error creating VPC: VpcLimitExceeded
```

**Cause**: Resource already exists or limit reached

**Solution**:
```bash
# Import existing resource
terraform import aws_vpc.main vpc-xxxxx

# Or delete existing resource
aws ec2 delete-vpc --vpc-id vpc-xxxxx

# Check limits
aws ec2 describe-account-attributes --attribute-names max-vpcs
```

### Issue: Terraform Plan Shows Unexpected Changes

**Error Message**:
```
Plan: 10 to add, 5 to change, 0 to destroy
```

**Cause**: State drift or manual changes

**Solution**:
```bash
# Refresh state
terraform refresh

# Show detailed diff
terraform plan -out=tfplan
terraform show tfplan

# If changes are expected, apply them
terraform apply tfplan

# If changes are not expected, investigate
terraform state list
terraform state show <resource>
```

## AWS Resource Issues

### Issue: EC2 Instance Launch Failure

**Error Message**:
```
Error: Error launching source instance: InsufficientInstanceCapacity
```

**Cause**: AWS doesn't have capacity in the requested AZ

**Solution**:
```bash
# Try different availability zone
# Update terraform.tfvars
availability_zones = ["us-east-1b", "us-east-1c"]

# Or try different instance type
instance_type = "t3.micro"  # instead of t2.micro

# Check instance limits
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-1216C47A
```

### Issue: RDS Creation Timeout

**Error Message**:
```
Error: timeout while waiting for state to become 'available'
```

**Cause**: RDS creation takes longer than expected (10-15 minutes)

**Solution**:
```bash
# Check RDS status in AWS Console or CLI
aws rds describe-db-instances \
  --db-instance-identifier <DB_ID> \
  --query 'DBInstances[0].DBInstanceStatus'

# Increase Terraform timeout
resource "aws_db_instance" "main" {
  # ... other config ...
  
  timeouts {
    create = "60m"
    update = "60m"
    delete = "60m"
  }
}

# Check for errors in RDS events
aws rds describe-events \
  --source-identifier <DB_ID> \
  --source-type db-instance
```

### Issue: S3 Bucket Already Exists

**Error Message**:
```
Error: Error creating S3 bucket: BucketAlreadyExists
```

**Cause**: S3 bucket names are globally unique

**Solution**:
```bash
# Use unique bucket name with account ID or random suffix
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "main" {
  bucket = "my-app-${data.aws_caller_identity.current.account_id}-${random_id.bucket_suffix.hex}"
}

# Or import existing bucket
terraform import aws_s3_bucket.main my-existing-bucket
```

## Network Connectivity

### Issue: Cannot SSH to EC2 Instance

**Symptoms**: Connection timeout when trying to SSH

**Diagnosis**:
```bash
# Check instance status
aws ec2 describe-instances \
  --instance-ids <INSTANCE_ID> \
  --query 'Reservations[0].Instances[0].[State.Name,PublicIpAddress,PrivateIpAddress]'

# Check security group rules
aws ec2 describe-security-groups \
  --group-ids <SG_ID> \
  --query 'SecurityGroups[0].IpPermissions'

# Check network ACLs
aws ec2 describe-network-acls \
  --filters "Name=association.subnet-id,Values=<SUBNET_ID>"

# Test connectivity
telnet <INSTANCE_IP> 22
nc -zv <INSTANCE_IP> 22
```

**Solutions**:

1. **Security Group Issue**:
```bash
# Add SSH rule
aws ec2 authorize-security-group-ingress \
  --group-id <SG_ID> \
  --protocol tcp \
  --port 22 \
  --cidr <YOUR_IP>/32
```

2. **Instance in Private Subnet**:
```bash
# Use bastion host
ssh -i key.pem -J ec2-user@<BASTION_IP> ec2-user@<PRIVATE_IP>

# Or use Systems Manager Session Manager
aws ssm start-session --target <INSTANCE_ID>
```

3. **No Public IP**:
```bash
# Allocate and associate Elastic IP
aws ec2 allocate-address
aws ec2 associate-address \
  --instance-id <INSTANCE_ID> \
  --allocation-id <EIP_ALLOCATION_ID>
```

### Issue: Load Balancer Health Checks Failing

**Symptoms**: Targets showing as unhealthy

**Diagnosis**:
```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn <TG_ARN>

# Check health check configuration
aws elbv2 describe-target-groups \
  --target-group-arns <TG_ARN> \
  --query 'TargetGroups[0].HealthCheckPath'

# Test health check endpoint
curl -I http://<INSTANCE_IP>:<PORT>/health
```

**Solutions**:

1. **Application Not Running**:
```bash
# SSH to instance and check service
ssh ec2-user@<INSTANCE_IP>
sudo systemctl status nginx  # or your application
sudo systemctl start nginx
```

2. **Wrong Health Check Path**:
```hcl
# Update health check configuration
resource "aws_lb_target_group" "main" {
  health_check {
    path                = "/health"  # Ensure this endpoint exists
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
  }
}
```

3. **Security Group Blocking**:
```bash
# Allow ALB to reach targets
aws ec2 authorize-security-group-ingress \
  --group-id <TARGET_SG_ID> \
  --protocol tcp \
  --port 80 \
  --source-group <ALB_SG_ID>
```

### Issue: VPC Peering Not Working

**Symptoms**: Cannot communicate between VPCs

**Diagnosis**:
```bash
# Check peering connection status
aws ec2 describe-vpc-peering-connections \
  --vpc-peering-connection-ids <PEERING_ID>

# Check route tables
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=<VPC_ID>"

# Test connectivity
ping <REMOTE_IP>
traceroute <REMOTE_IP>
```

**Solutions**:

1. **Accept Peering Connection**:
```bash
aws ec2 accept-vpc-peering-connection \
  --vpc-peering-connection-id <PEERING_ID>
```

2. **Add Routes**:
```bash
# Add route to peering connection
aws ec2 create-route \
  --route-table-id <RT_ID> \
  --destination-cidr-block <REMOTE_VPC_CIDR> \
  --vpc-peering-connection-id <PEERING_ID>
```

3. **Update Security Groups**:
```bash
# Allow traffic from peered VPC
aws ec2 authorize-security-group-ingress \
  --group-id <SG_ID> \
  --protocol -1 \
  --cidr <REMOTE_VPC_CIDR>
```

## Database Issues

### Issue: Cannot Connect to RDS

**Symptoms**: Connection timeout or authentication failure

**Diagnosis**:
```bash
# Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier <DB_ID> \
  --query 'DBInstances[0].[DBInstanceStatus,Endpoint.Address,Endpoint.Port]'

# Check security group
aws rds describe-db-instances \
  --db-instance-identifier <DB_ID> \
  --query 'DBInstances[0].VpcSecurityGroups'

# Test connectivity
telnet <RDS_ENDPOINT> 5432
nc -zv <RDS_ENDPOINT> 5432

# Test with psql
psql -h <RDS_ENDPOINT> -U <USERNAME> -d <DATABASE>
```

**Solutions**:

1. **Security Group Issue**:
```bash
# Allow application tier to access database
aws ec2 authorize-security-group-ingress \
  --group-id <DB_SG_ID> \
  --protocol tcp \
  --port 5432 \
  --source-group <APP_SG_ID>
```

2. **Wrong Credentials**:
```bash
# Retrieve password from Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id rds-db-password \
  --query SecretString \
  --output text

# Reset password
aws rds modify-db-instance \
  --db-instance-identifier <DB_ID> \
  --master-user-password <NEW_PASSWORD> \
  --apply-immediately
```

3. **Database Not Ready**:
```bash
# Wait for database to be available
aws rds wait db-instance-available \
  --db-instance-identifier <DB_ID>
```

### Issue: High Replication Lag

**Symptoms**: Read replica lagging behind primary

**Diagnosis**:
```bash
# Check replication lag
aws rds describe-db-instances \
  --db-instance-identifier <REPLICA_ID> \
  --query 'DBInstances[0].StatusInfos'

# Check CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name ReplicaLag \
  --dimensions Name=DBInstanceIdentifier,Value=<REPLICA_ID> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

**Solutions**:

1. **High Write Load**:
```bash
# Scale up primary instance
aws rds modify-db-instance \
  --db-instance-identifier <PRIMARY_ID> \
  --db-instance-class db.t3.small \
  --apply-immediately
```

2. **Network Issues**:
```bash
# Check VPC peering or VPN connection
# Verify cross-region bandwidth
```

3. **Long-Running Queries**:
```sql
-- Connect to primary and check for long-running queries
SELECT pid, now() - pg_stat_activity.query_start AS duration, query 
FROM pg_stat_activity 
WHERE state = 'active' 
ORDER BY duration DESC;

-- Kill long-running query if necessary
SELECT pg_terminate_backend(pid);
```

## Application Issues

### Issue: Application Not Starting

**Symptoms**: Service fails to start on EC2 instance

**Diagnosis**:
```bash
# SSH to instance
ssh ec2-user@<INSTANCE_IP>

# Check service status
sudo systemctl status <SERVICE_NAME>

# Check logs
sudo journalctl -u <SERVICE_NAME> -n 50
sudo tail -f /var/log/<APP_LOG>

# Check application errors
cat /var/log/application.log
```

**Solutions**:

1. **Missing Dependencies**:
```bash
# Install dependencies
sudo yum install -y <PACKAGE>
sudo pip install -r requirements.txt
sudo npm install
```

2. **Configuration Error**:
```bash
# Check configuration file
cat /etc/<APP>/config.yml

# Validate configuration
<APP> --validate-config

# Fix permissions
sudo chown -R <APP_USER>:<APP_GROUP> /etc/<APP>
```

3. **Port Already in Use**:
```bash
# Check what's using the port
sudo netstat -tulpn | grep :<PORT>
sudo lsof -i :<PORT>

# Kill process or change port
sudo kill <PID>
```

### Issue: High CPU Usage

**Symptoms**: EC2 instances showing high CPU utilization

**Diagnosis**:
```bash
# Check CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=<INSTANCE_ID> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum

# SSH to instance and check processes
ssh ec2-user@<INSTANCE_IP>
top
htop
ps aux --sort=-%cpu | head -10
```

**Solutions**:

1. **Scale Up**:
```bash
# Increase instance size
aws ec2 stop-instances --instance-ids <INSTANCE_ID>
aws ec2 modify-instance-attribute \
  --instance-id <INSTANCE_ID> \
  --instance-type t3.small
aws ec2 start-instances --instance-ids <INSTANCE_ID>
```

2. **Scale Out**:
```bash
# Increase Auto Scaling Group capacity
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name <ASG_NAME> \
  --desired-capacity 4
```

3. **Optimize Application**:
```bash
# Profile application
# Identify bottlenecks
# Optimize code or queries
```

## Monitoring and Logging

### Issue: CloudWatch Logs Not Appearing

**Symptoms**: Logs not showing up in CloudWatch

**Diagnosis**:
```bash
# Check CloudWatch agent status
ssh ec2-user@<INSTANCE_IP>
sudo systemctl status amazon-cloudwatch-agent

# Check agent configuration
sudo cat /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# Check IAM role permissions
aws iam get-role --role-name <EC2_ROLE>
aws iam list-attached-role-policies --role-name <EC2_ROLE>
```

**Solutions**:

1. **Agent Not Running**:
```bash
# Start CloudWatch agent
sudo systemctl start amazon-cloudwatch-agent
sudo systemctl enable amazon-cloudwatch-agent
```

2. **Wrong Configuration**:
```bash
# Update configuration
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
```

3. **Missing IAM Permissions**:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ],
    "Resource": "*"
  }]
}
```

### Issue: Alarms Not Triggering

**Symptoms**: CloudWatch alarms not sending notifications

**Diagnosis**:
```bash
# Check alarm configuration
aws cloudwatch describe-alarms \
  --alarm-names <ALARM_NAME>

# Check alarm history
aws cloudwatch describe-alarm-history \
  --alarm-name <ALARM_NAME> \
  --max-records 10

# Check SNS topic
aws sns get-topic-attributes \
  --topic-arn <TOPIC_ARN>

# Check SNS subscriptions
aws sns list-subscriptions-by-topic \
  --topic-arn <TOPIC_ARN>
```

**Solutions**:

1. **Alarm Threshold Too High**:
```bash
# Update alarm threshold
aws cloudwatch put-metric-alarm \
  --alarm-name <ALARM_NAME> \
  --threshold 80  # Lower threshold
```

2. **SNS Subscription Not Confirmed**:
```bash
# Check email for confirmation link
# Or resend confirmation
aws sns subscribe \
  --topic-arn <TOPIC_ARN> \
  --protocol email \
  --notification-endpoint <EMAIL>
```

3. **Insufficient Data**:
```bash
# Check if metrics are being published
aws cloudwatch get-metric-statistics \
  --namespace <NAMESPACE> \
  --metric-name <METRIC> \
  --dimensions Name=<DIM_NAME>,Value=<DIM_VALUE> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

## Security Issues

### Issue: Access Denied Errors

**Symptoms**: AWS API calls returning AccessDenied

**Diagnosis**:
```bash
# Check current identity
aws sts get-caller-identity

# Check IAM user/role permissions
aws iam get-user-policy --user-name <USER> --policy-name <POLICY>
aws iam list-attached-user-policies --user-name <USER>

# Simulate policy
aws iam simulate-principal-policy \
  --policy-source-arn <USER_ARN> \
  --action-names <ACTION> \
  --resource-arns <RESOURCE_ARN>
```

**Solutions**:

1. **Missing Permissions**:
```bash
# Attach required policy
aws iam attach-user-policy \
  --user-name <USER> \
  --policy-arn <POLICY_ARN>
```

2. **Resource Policy Blocking**:
```bash
# Check resource policy (S3, KMS, etc.)
aws s3api get-bucket-policy --bucket <BUCKET>
aws kms get-key-policy --key-id <KEY_ID> --policy-name default
```

### Issue: KMS Encryption Errors

**Symptoms**: Cannot encrypt/decrypt data

**Diagnosis**:
```bash
# Check KMS key status
aws kms describe-key --key-id <KEY_ID>

# Check key policy
aws kms get-key-policy \
  --key-id <KEY_ID> \
  --policy-name default

# Test encryption
aws kms encrypt \
  --key-id <KEY_ID> \
  --plaintext "test" \
  --query CiphertextBlob \
  --output text
```

**Solutions**:

1. **Key Disabled**:
```bash
# Enable key
aws kms enable-key --key-id <KEY_ID>
```

2. **Missing Key Permissions**:
```json
{
  "Sid": "Allow use of the key",
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::ACCOUNT:role/ROLE"
  },
  "Action": [
    "kms:Encrypt",
    "kms:Decrypt",
    "kms:GenerateDataKey"
  ],
  "Resource": "*"
}
```

## Getting Help

### AWS Support

```bash
# Create support case
aws support create-case \
  --subject "Issue with RDS" \
  --service-code "amazon-rds" \
  --severity-code "high" \
  --category-code "performance" \
  --communication-body "Description of issue"
```

### Community Resources

- [AWS Forums](https://forums.aws.amazon.com/)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/amazon-web-services)
- [Terraform Community](https://discuss.hashicorp.com/c/terraform-core)

### Internal Escalation

1. Check this troubleshooting guide
2. Review [Architecture Documentation](ARCHITECTURE.md)
3. Check [DR Runbook](RUNBOOK.md)
4. Contact on-call engineer
5. Escalate to AWS Support if needed

---

**Document Maintenance**: Update this guide when new issues are discovered and resolved.
