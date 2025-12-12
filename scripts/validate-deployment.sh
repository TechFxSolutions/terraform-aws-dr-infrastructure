#!/bin/bash
# Deployment Validation Script
# Validates that all infrastructure components are deployed correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Function to print colored output
print_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
}

print_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
}

print_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# Load environment variables from .env file if it exists
if [ -f ".env" ]; then
    print_info "Loading AWS credentials from .env file..."
    set -a
    source .env
    set +a
    print_info "AWS credentials loaded from .env"
fi

# Function to check AWS resource
check_resource() {
    local resource_type=$1
    local resource_id=$2
    local region=$3
    local description=$4
    
    case $resource_type in
        "ec2")
            if aws ec2 describe-instances --instance-ids "$resource_id" --region "$region" &>/dev/null; then
                print_pass "$description"
            else
                print_fail "$description"
            fi
            ;;
        "rds")
            if aws rds describe-db-instances --db-instance-identifier "$resource_id" --region "$region" &>/dev/null; then
                print_pass "$description"
            else
                print_fail "$description"
            fi
            ;;
        "alb")
            if aws elbv2 describe-load-balancers --load-balancer-arns "$resource_id" --region "$region" &>/dev/null; then
                print_pass "$description"
            else
                print_fail "$description"
            fi
            ;;
        "s3")
            if aws s3 ls "s3://$resource_id" &>/dev/null; then
                print_pass "$description"
            else
                print_fail "$description"
            fi
            ;;
        "vpc")
            if aws ec2 describe-vpcs --vpc-ids "$resource_id" --region "$region" &>/dev/null; then
                print_pass "$description"
            else
                print_fail "$description"
            fi
            ;;
    esac
}

echo "=========================================="
echo "  Infrastructure Validation"
echo "=========================================="
echo ""

# Check if AWS CLI is configured
print_info "Checking AWS credentials..."
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    print_fail "AWS credentials not configured"
    echo ""
    echo "Please configure AWS credentials using one of these methods:"
    echo "1. Create .env file from .env.example and add your credentials"
    echo "2. Run 'aws configure'"
    echo "3. Set environment variables: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY"
    exit 1
fi
print_pass "AWS credentials configured"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
print_info "AWS Account: $ACCOUNT_ID"
echo ""

# Validate Primary Region
print_info "Validating Primary Region (us-east-1)..."
echo ""

cd "$PROJECT_ROOT/environments/primary"

if [ ! -f ".terraform/terraform.tfstate" ]; then
    print_warn "Primary region not initialized. Run terraform init first."
else
    # Get outputs
    VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
    ALB_ARN=$(terraform output -raw alb_arn 2>/dev/null || echo "")
    DB_ID=$(terraform output -raw db_instance_id 2>/dev/null || echo "")
    WEB_ASG=$(terraform output -raw web_asg_name 2>/dev/null || echo "")
    APP_ASG=$(terraform output -raw app_asg_name 2>/dev/null || echo "")
    
    # Check VPC
    if [ -n "$VPC_ID" ]; then
        check_resource "vpc" "$VPC_ID" "us-east-1" "Primary VPC exists"
    else
        print_warn "Primary VPC ID not found in outputs"
    fi
    
    # Check ALB
    if [ -n "$ALB_ARN" ]; then
        check_resource "alb" "$ALB_ARN" "us-east-1" "Primary ALB exists"
        
        # Check ALB health
        HEALTHY_TARGETS=$(aws elbv2 describe-target-health \
            --target-group-arn "$(terraform output -raw web_target_group_arn 2>/dev/null)" \
            --region us-east-1 \
            --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`] | length(@)' \
            --output text 2>/dev/null || echo "0")
        
        if [ "$HEALTHY_TARGETS" -gt 0 ]; then
            print_pass "Primary ALB has $HEALTHY_TARGETS healthy targets"
        else
            print_warn "Primary ALB has no healthy targets"
        fi
    else
        print_warn "Primary ALB ARN not found in outputs"
    fi
    
    # Check RDS
    if [ -n "$DB_ID" ]; then
        check_resource "rds" "$DB_ID" "us-east-1" "Primary RDS instance exists"
        
        # Check RDS status
        DB_STATUS=$(aws rds describe-db-instances \
            --db-instance-identifier "$DB_ID" \
            --region us-east-1 \
            --query 'DBInstances[0].DBInstanceStatus' \
            --output text 2>/dev/null || echo "unknown")
        
        if [ "$DB_STATUS" == "available" ]; then
            print_pass "Primary RDS status: available"
        else
            print_warn "Primary RDS status: $DB_STATUS"
        fi
    else
        print_warn "Primary RDS ID not found in outputs"
    fi
    
    # Check Auto Scaling Groups
    if [ -n "$WEB_ASG" ]; then
        WEB_INSTANCES=$(aws autoscaling describe-auto-scaling-groups \
            --auto-scaling-group-names "$WEB_ASG" \
            --region us-east-1 \
            --query 'AutoScalingGroups[0].Instances | length(@)' \
            --output text 2>/dev/null || echo "0")
        
        if [ "$WEB_INSTANCES" -gt 0 ]; then
            print_pass "Primary Web ASG has $WEB_INSTANCES instances"
        else
            print_warn "Primary Web ASG has no instances"
        fi
    fi
    
    if [ -n "$APP_ASG" ]; then
        APP_INSTANCES=$(aws autoscaling describe-auto-scaling-groups \
            --auto-scaling-group-names "$APP_ASG" \
            --region us-east-1 \
            --query 'AutoScalingGroups[0].Instances | length(@)' \
            --output text 2>/dev/null || echo "0")
        
        if [ "$APP_INSTANCES" -gt 0 ]; then
            print_pass "Primary App ASG has $APP_INSTANCES instances"
        else
            print_warn "Primary App ASG has no instances"
        fi
    fi
fi

echo ""

# Validate Secondary Region
print_info "Validating Secondary Region (us-west-2)..."
echo ""

cd "$PROJECT_ROOT/environments/secondary"

if [ ! -f ".terraform/terraform.tfstate" ]; then
    print_warn "Secondary region not initialized. Run terraform init first."
else
    # Get outputs
    VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
    ALB_ARN=$(terraform output -raw alb_arn 2>/dev/null || echo "")
    DB_ID=$(terraform output -raw db_instance_id 2>/dev/null || echo "")
    
    # Check VPC
    if [ -n "$VPC_ID" ]; then
        check_resource "vpc" "$VPC_ID" "us-west-2" "Secondary VPC exists"
    else
        print_warn "Secondary VPC ID not found in outputs"
    fi
    
    # Check ALB
    if [ -n "$ALB_ARN" ]; then
        check_resource "alb" "$ALB_ARN" "us-west-2" "Secondary ALB exists"
    else
        print_warn "Secondary ALB ARN not found in outputs"
    fi
    
    # Check RDS Replica
    if [ -n "$DB_ID" ]; then
        check_resource "rds" "$DB_ID" "us-west-2" "Secondary RDS replica exists"
        
        # Check replication lag
        REPLICA_LAG=$(aws rds describe-db-instances \
            --db-instance-identifier "$DB_ID" \
            --region us-west-2 \
            --query 'DBInstances[0].StatusInfos[?StatusType==`read replication`].Status' \
            --output text 2>/dev/null || echo "unknown")
        
        if [ -n "$REPLICA_LAG" ]; then
            print_pass "Secondary RDS replication active"
        else
            print_warn "Secondary RDS replication status unknown"
        fi
    else
        print_warn "Secondary RDS ID not found in outputs"
    fi
fi

cd "$PROJECT_ROOT"

echo ""
echo "=========================================="
echo "  Validation Summary"
echo "=========================================="
echo ""
echo -e "${GREEN}Passed:${NC} $PASSED"
echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
echo -e "${RED}Failed:${NC} $FAILED"
echo ""

if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Validation FAILED${NC}"
    echo "Please review the failed checks and fix the issues."
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}Validation completed with WARNINGS${NC}"
    echo "Review the warnings to ensure everything is configured correctly."
    exit 0
else
    echo -e "${GREEN}Validation PASSED${NC}"
    echo "All infrastructure components are deployed correctly!"
    exit 0
fi
