#!/bin/bash
# Complete Deployment Script for DR Infrastructure
# This script deploys the entire infrastructure in the correct order

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
print_info "Checking prerequisites..."

if ! command_exists terraform; then
    print_error "Terraform is not installed. Please install Terraform >= 1.6.0"
    exit 1
fi

if ! command_exists aws; then
    print_error "AWS CLI is not installed. Please install AWS CLI"
    exit 1
fi

# Verify AWS credentials
print_info "Verifying AWS credentials..."
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    print_error "AWS credentials are not configured. Run 'aws configure'"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
print_info "Using AWS Account: $ACCOUNT_ID"

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# Step 1: Deploy S3 Backend
print_info "Step 1/5: Deploying S3 backend for Terraform state..."
cd global/s3-backend

if [ ! -f "terraform.tfstate" ]; then
    terraform init
    terraform plan -out=tfplan
    terraform apply tfplan
    
    # Save backend configuration
    STATE_BUCKET=$(terraform output -raw s3_bucket_name)
    LOCK_TABLE=$(terraform output -raw dynamodb_table_name)
    
    print_info "S3 Backend created:"
    print_info "  Bucket: $STATE_BUCKET"
    print_info "  Lock Table: $LOCK_TABLE"
    
    # Save to file for later use
    echo "export TF_STATE_BUCKET=$STATE_BUCKET" > "$PROJECT_ROOT/.env"
    echo "export TF_STATE_LOCK_TABLE=$LOCK_TABLE" >> "$PROJECT_ROOT/.env"
else
    print_warn "S3 backend already exists, skipping..."
    STATE_BUCKET=$(terraform output -raw s3_bucket_name)
    LOCK_TABLE=$(terraform output -raw dynamodb_table_name)
fi

cd "$PROJECT_ROOT"

# Step 2: Deploy Global IAM Resources
print_info "Step 2/5: Deploying global IAM resources..."
cd global/iam

terraform init \
    -backend-config="bucket=$STATE_BUCKET" \
    -backend-config="key=global/iam/terraform.tfstate" \
    -backend-config="region=us-east-1" \
    -backend-config="dynamodb_table=$LOCK_TABLE"

terraform plan -out=tfplan
terraform apply tfplan

print_info "Global IAM resources deployed"

cd "$PROJECT_ROOT"

# Step 3: Deploy Primary Region
print_info "Step 3/5: Deploying primary region infrastructure..."
cd environments/primary

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    print_error "terraform.tfvars not found in environments/primary/"
    print_error "Please copy terraform.tfvars.example to terraform.tfvars and configure it"
    exit 1
fi

# Update terraform.tfvars with backend info
if ! grep -q "terraform_state_bucket" terraform.tfvars; then
    echo "" >> terraform.tfvars
    echo "# Terraform State Configuration (auto-generated)" >> terraform.tfvars
    echo "terraform_state_bucket = \"$STATE_BUCKET\"" >> terraform.tfvars
    echo "terraform_state_region = \"us-east-1\"" >> terraform.tfvars
fi

terraform init \
    -backend-config="bucket=$STATE_BUCKET" \
    -backend-config="key=primary/terraform.tfstate" \
    -backend-config="region=us-east-1" \
    -backend-config="dynamodb_table=$LOCK_TABLE"

terraform plan -out=tfplan
terraform apply tfplan

# Save primary outputs
PRIMARY_DB_ARN=$(terraform output -raw db_instance_id)
PRIMARY_BACKUPS_BUCKET=$(terraform output -raw backups_bucket_name)
PRIMARY_S3_KMS_KEY=$(terraform output -json | jq -r '.storage_kms_key_arn.value // empty')

print_info "Primary region deployed successfully"
print_info "  Database: $PRIMARY_DB_ARN"
print_info "  Backups Bucket: $PRIMARY_BACKUPS_BUCKET"

cd "$PROJECT_ROOT"

# Step 4: Deploy Secondary Region
print_info "Step 4/5: Deploying secondary region infrastructure..."
cd environments/secondary

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    print_error "terraform.tfvars not found in environments/secondary/"
    print_error "Please copy terraform.tfvars.example to terraform.tfvars and configure it"
    exit 1
fi

# Update terraform.tfvars with backend info and primary region details
if ! grep -q "terraform_state_bucket" terraform.tfvars; then
    echo "" >> terraform.tfvars
    echo "# Terraform State Configuration (auto-generated)" >> terraform.tfvars
    echo "terraform_state_bucket = \"$STATE_BUCKET\"" >> terraform.tfvars
    echo "terraform_state_region = \"us-east-1\"" >> terraform.tfvars
fi

# Update source_db_identifier if not set
if ! grep -q "^source_db_identifier" terraform.tfvars; then
    echo "" >> terraform.tfvars
    echo "# Primary Database Configuration (auto-generated)" >> terraform.tfvars
    echo "source_db_identifier = \"arn:aws:rds:us-east-1:$ACCOUNT_ID:db:$PRIMARY_DB_ARN\"" >> terraform.tfvars
fi

terraform init \
    -backend-config="bucket=$STATE_BUCKET" \
    -backend-config="key=secondary/terraform.tfstate" \
    -backend-config="region=us-east-1" \
    -backend-config="dynamodb_table=$LOCK_TABLE"

terraform plan -out=tfplan
terraform apply tfplan

print_info "Secondary region deployed successfully"

cd "$PROJECT_ROOT"

# Step 5: Summary
print_info "Step 5/5: Deployment Summary"
echo ""
echo "=========================================="
echo "  DEPLOYMENT COMPLETE!"
echo "=========================================="
echo ""
echo "Infrastructure deployed successfully in both regions."
echo ""
echo "Primary Region (us-east-1):"
cd environments/primary
echo "  Application URL: $(terraform output -raw application_url)"
echo "  Bastion IP: $(terraform output -raw bastion_public_ip || echo 'Not enabled')"
echo ""
cd "$PROJECT_ROOT"

echo "Secondary Region (us-west-2):"
cd environments/secondary
echo "  Application URL: $(terraform output -raw application_url)"
echo "  Status: STANDBY MODE"
echo ""
cd "$PROJECT_ROOT"

echo "Next Steps:"
echo "1. Configure DNS to point to primary region ALB"
echo "2. Deploy your application code"
echo "3. Test failover procedures (see docs/RUNBOOK.md)"
echo "4. Set up monitoring alerts"
echo ""
echo "For detailed information, see:"
echo "  - Architecture: docs/ARCHITECTURE.md"
echo "  - Deployment: docs/DEPLOYMENT.md"
echo "  - DR Runbook: docs/RUNBOOK.md"
echo ""

print_info "Deployment script completed successfully!"
