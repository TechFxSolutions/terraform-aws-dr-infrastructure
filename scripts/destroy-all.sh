#!/bin/bash
# Destroy All Infrastructure Script
# WARNING: This will destroy ALL infrastructure in both regions!

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "  DESTROY ALL INFRASTRUCTURE"
echo "=========================================="
echo ""
print_warn "This will PERMANENTLY DELETE all infrastructure!"
print_warn "This action CANNOT be undone!"
echo ""
read -p "Are you sure you want to continue? (type 'yes' to confirm): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    print_info "Destruction cancelled."
    exit 0
fi

echo ""
read -p "Type the project name 'terraform-dr-infrastructure' to confirm: " PROJECT_CONFIRM

if [ "$PROJECT_CONFIRM" != "terraform-dr-infrastructure" ]; then
    print_error "Project name does not match. Destruction cancelled."
    exit 1
fi

print_warn "Starting destruction in 10 seconds... Press Ctrl+C to cancel"
sleep 10

cd "$PROJECT_ROOT"

# Load environment variables if they exist
if [ -f ".env" ]; then
    source .env
fi

# Step 1: Destroy Secondary Region
print_info "Step 1/4: Destroying secondary region infrastructure..."
cd environments/secondary

if [ -f ".terraform/terraform.tfstate" ]; then
    terraform destroy -auto-approve
    print_info "Secondary region destroyed"
else
    print_warn "Secondary region not initialized, skipping..."
fi

cd "$PROJECT_ROOT"

# Step 2: Destroy Primary Region
print_info "Step 2/4: Destroying primary region infrastructure..."
cd environments/primary

if [ -f ".terraform/terraform.tfstate" ]; then
    terraform destroy -auto-approve
    print_info "Primary region destroyed"
else
    print_warn "Primary region not initialized, skipping..."
fi

cd "$PROJECT_ROOT"

# Step 3: Destroy Global IAM Resources
print_info "Step 3/4: Destroying global IAM resources..."
cd global/iam

if [ -f ".terraform/terraform.tfstate" ]; then
    terraform destroy -auto-approve
    print_info "Global IAM resources destroyed"
else
    print_warn "Global IAM not initialized, skipping..."
fi

cd "$PROJECT_ROOT"

# Step 4: Destroy S3 Backend (Optional)
print_info "Step 4/4: S3 Backend cleanup..."
cd global/s3-backend

if [ -f "terraform.tfstate" ]; then
    echo ""
    print_warn "S3 Backend contains Terraform state files"
    read -p "Do you want to destroy the S3 backend? (yes/no): " DESTROY_BACKEND
    
    if [ "$DESTROY_BACKEND" == "yes" ]; then
        # Empty S3 bucket first
        STATE_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")
        if [ -n "$STATE_BUCKET" ]; then
            print_info "Emptying S3 bucket: $STATE_BUCKET"
            aws s3 rm "s3://$STATE_BUCKET" --recursive || true
            
            # Delete all versions
            aws s3api list-object-versions \
                --bucket "$STATE_BUCKET" \
                --query 'Versions[].{Key:Key,VersionId:VersionId}' \
                --output json | \
                jq -r '.[] | "--key \(.Key) --version-id \(.VersionId)"' | \
                xargs -I {} aws s3api delete-object --bucket "$STATE_BUCKET" {} || true
        fi
        
        terraform destroy -auto-approve
        print_info "S3 backend destroyed"
    else
        print_info "S3 backend preserved"
    fi
else
    print_warn "S3 backend not found, skipping..."
fi

cd "$PROJECT_ROOT"

# Cleanup local files
print_info "Cleaning up local files..."
rm -f .env
find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
find . -type f -name "terraform.tfstate*" -delete 2>/dev/null || true
find . -type f -name ".terraform.lock.hcl" -delete 2>/dev/null || true

echo ""
echo "=========================================="
echo "  DESTRUCTION COMPLETE"
echo "=========================================="
echo ""
print_info "All infrastructure has been destroyed."
echo ""
echo "Remaining manual cleanup (if needed):"
echo "1. Check AWS Console for any remaining resources"
echo "2. Review CloudWatch Logs for any retained log groups"
echo "3. Check S3 for any remaining buckets"
echo "4. Review IAM for any orphaned roles/policies"
echo ""
print_info "Destruction script completed."
