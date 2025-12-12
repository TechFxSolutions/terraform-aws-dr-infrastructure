#!/bin/bash
# Force Destroy S3 Backend
# Use this if destroy-all.sh fails to remove the S3 backend

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

cd "$PROJECT_ROOT"

# Load environment variables from .env file if it exists
if [ -f ".env" ]; then
    print_info "Loading AWS credentials from .env file..."
    set -a
    source .env
    set +a
fi

echo "=========================================="
echo "  FORCE DESTROY S3 BACKEND"
echo "=========================================="
echo ""
print_warn "This will forcefully destroy the S3 backend!"
print_warn "This bypasses prevent_destroy protection!"
echo ""
read -p "Are you sure? (type 'yes' to confirm): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    print_info "Operation cancelled."
    exit 0
fi

cd global/s3-backend

# Check if terraform state exists
if [ ! -f "terraform.tfstate" ]; then
    print_error "No terraform.tfstate found in global/s3-backend/"
    exit 1
fi

# Get bucket and table names
print_info "Reading current state..."
STATE_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")
LOCK_TABLE=$(terraform output -raw dynamodb_table_name 2>/dev/null || echo "")

if [ -z "$STATE_BUCKET" ]; then
    print_error "Could not determine S3 bucket name from state"
    exit 1
fi

print_info "Found resources:"
echo "  S3 Bucket: $STATE_BUCKET"
echo "  DynamoDB Table: $LOCK_TABLE"
echo ""

# Step 1: Empty S3 bucket
print_info "Step 1/4: Emptying S3 bucket..."

# Delete all objects
aws s3 rm "s3://$STATE_BUCKET" --recursive 2>/dev/null || true

# Delete all versions
print_info "Deleting all object versions..."
aws s3api list-object-versions \
    --bucket "$STATE_BUCKET" \
    --output json 2>/dev/null | \
    jq -r '.Versions[]? | "--key \"\(.Key)\" --version-id \(.VersionId)"' | \
    while read -r args; do
        eval aws s3api delete-object --bucket "$STATE_BUCKET" $args 2>/dev/null || true
    done

# Delete all delete markers
print_info "Deleting all delete markers..."
aws s3api list-object-versions \
    --bucket "$STATE_BUCKET" \
    --output json 2>/dev/null | \
    jq -r '.DeleteMarkers[]? | "--key \"\(.Key)\" --version-id \(.VersionId)"' | \
    while read -r args; do
        eval aws s3api delete-object --bucket "$STATE_BUCKET" $args 2>/dev/null || true
    done

print_info "S3 bucket emptied"

# Step 2: Remove prevent_destroy from Terraform config
print_info "Step 2/4: Removing prevent_destroy protection..."

if [ -f "main.tf" ]; then
    # Backup original
    cp main.tf main.tf.backup
    
    # Remove lifecycle blocks
    cat main.tf | sed '/lifecycle {/,/}/d' > main.tf.tmp
    mv main.tf.tmp main.tf
    
    print_info "prevent_destroy protection removed"
fi

# Step 3: Destroy with Terraform
print_info "Step 3/4: Destroying resources with Terraform..."

if terraform destroy -auto-approve; then
    print_info "Terraform destroy successful"
    rm -f main.tf.backup
else
    print_warn "Terraform destroy failed, attempting manual cleanup..."
    
    # Restore original main.tf
    if [ -f "main.tf.backup" ]; then
        mv main.tf.backup main.tf
    fi
    
    # Manual cleanup
    print_info "Step 4/4: Manual cleanup..."
    
    # Delete S3 bucket
    if [ -n "$STATE_BUCKET" ]; then
        print_info "Deleting S3 bucket: $STATE_BUCKET"
        aws s3 rb "s3://$STATE_BUCKET" --force 2>/dev/null || \
            aws s3api delete-bucket --bucket "$STATE_BUCKET" 2>/dev/null || \
            print_warn "Could not delete S3 bucket (may need manual deletion)"
    fi
    
    # Delete DynamoDB table
    if [ -n "$LOCK_TABLE" ]; then
        print_info "Deleting DynamoDB table: $LOCK_TABLE"
        aws dynamodb delete-table --table-name "$LOCK_TABLE" 2>/dev/null || \
            print_warn "Could not delete DynamoDB table (may need manual deletion)"
    fi
fi

# Step 4: Clean up local state
print_info "Cleaning up local state files..."
rm -f terraform.tfstate*
rm -f .terraform.lock.hcl
rm -rf .terraform/
rm -f backend-config.txt

cd "$PROJECT_ROOT"

echo ""
echo "=========================================="
echo "  FORCE DESTROY COMPLETE"
echo "=========================================="
echo ""

# Verify resources are gone
print_info "Verifying deletion..."

if [ -n "$STATE_BUCKET" ]; then
    if aws s3 ls "s3://$STATE_BUCKET" 2>/dev/null; then
        print_warn "S3 bucket still exists: $STATE_BUCKET"
        echo "  Manual deletion: aws s3 rb s3://$STATE_BUCKET --force"
    else
        print_info "S3 bucket deleted: $STATE_BUCKET"
    fi
fi

if [ -n "$LOCK_TABLE" ]; then
    if aws dynamodb describe-table --table-name "$LOCK_TABLE" 2>/dev/null; then
        print_warn "DynamoDB table still exists: $LOCK_TABLE"
        echo "  Manual deletion: aws dynamodb delete-table --table-name $LOCK_TABLE"
    else
        print_info "DynamoDB table deleted: $LOCK_TABLE"
    fi
fi

echo ""
print_info "Backend destruction complete!"
