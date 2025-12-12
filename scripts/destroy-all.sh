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

cd "$PROJECT_ROOT"

# Load environment variables from .env file if it exists
if [ -f ".env" ]; then
    print_info "Loading AWS credentials from .env file..."
    set -a
    source .env
    set +a
    print_info "AWS credentials loaded from .env"
fi

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

# Step 4: Destroy S3 Backend (with prevent_destroy handling)
print_info "Step 4/4: S3 Backend cleanup..."
cd global/s3-backend

if [ -f "terraform.tfstate" ]; then
    echo ""
    print_warn "S3 Backend contains Terraform state files and has prevent_destroy protection"
    read -p "Do you want to destroy the S3 backend? (yes/no): " DESTROY_BACKEND
    
    if [ "$DESTROY_BACKEND" == "yes" ]; then
        # Get bucket name before destroying
        STATE_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")
        LOCK_TABLE=$(terraform output -raw dynamodb_table_name 2>/dev/null || echo "")
        
        if [ -n "$STATE_BUCKET" ]; then
            print_info "Emptying S3 bucket: $STATE_BUCKET"
            
            # Empty the bucket (delete all objects and versions)
            aws s3 rm "s3://$STATE_BUCKET" --recursive 2>/dev/null || true
            
            # Delete all object versions
            print_info "Deleting all object versions..."
            aws s3api list-object-versions \
                --bucket "$STATE_BUCKET" \
                --output json 2>/dev/null | \
                jq -r '.Versions[]? | "--key \"\(.Key)\" --version-id \(.VersionId)"' | \
                xargs -I {} aws s3api delete-object --bucket "$STATE_BUCKET" {} 2>/dev/null || true
            
            # Delete all delete markers
            print_info "Deleting all delete markers..."
            aws s3api list-object-versions \
                --bucket "$STATE_BUCKET" \
                --output json 2>/dev/null | \
                jq -r '.DeleteMarkers[]? | "--key \"\(.Key)\" --version-id \(.VersionId)"' | \
                xargs -I {} aws s3api delete-object --bucket "$STATE_BUCKET" {} 2>/dev/null || true
        fi
        
        # Remove prevent_destroy from the Terraform configuration temporarily
        print_info "Removing prevent_destroy protection..."
        
        # Create a temporary main.tf without prevent_destroy
        if [ -f "main.tf" ]; then
            # Backup original
            cp main.tf main.tf.backup
            
            # Remove lifecycle blocks with prevent_destroy
            sed -i.tmp '/lifecycle {/,/}/d' main.tf
            rm -f main.tf.tmp
            
            print_info "Attempting to destroy S3 backend..."
            
            # Try to destroy
            if terraform destroy -auto-approve; then
                print_info "S3 backend destroyed successfully"
                rm -f main.tf.backup
            else
                print_error "Failed to destroy S3 backend"
                # Restore original file
                mv main.tf.backup main.tf
                
                # Manual cleanup instructions
                echo ""
                print_warn "Automatic destruction failed. Manual cleanup required:"
                echo ""
                echo "1. Delete S3 bucket manually:"
                if [ -n "$STATE_BUCKET" ]; then
                    echo "   aws s3 rb s3://$STATE_BUCKET --force"
                fi
                echo ""
                echo "2. Delete DynamoDB table manually:"
                if [ -n "$LOCK_TABLE" ]; then
                    echo "   aws dynamodb delete-table --table-name $LOCK_TABLE"
                fi
                echo ""
                echo "3. Then remove the Terraform state:"
                echo "   rm -f global/s3-backend/terraform.tfstate*"
            fi
        fi
    else
        print_info "S3 backend preserved"
        echo ""
        print_warn "Note: S3 backend still exists with the following resources:"
        if [ -n "$STATE_BUCKET" ]; then
            echo "  - S3 Bucket: $STATE_BUCKET"
        fi
        if [ -n "$LOCK_TABLE" ]; then
            echo "  - DynamoDB Table: $LOCK_TABLE"
        fi
        echo ""
        echo "To destroy manually later:"
        echo "  1. cd global/s3-backend"
        echo "  2. Edit main.tf and remove 'lifecycle { prevent_destroy = true }' blocks"
        echo "  3. terraform destroy"
    fi
else
    print_warn "S3 backend not found, skipping..."
fi

cd "$PROJECT_ROOT"

# Cleanup local files
print_info "Cleaning up local files..."
find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
find . -type f -name "terraform.tfstate*" -delete 2>/dev/null || true
find . -type f -name ".terraform.lock.hcl" -delete 2>/dev/null || true

echo ""
echo "=========================================="
echo "  DESTRUCTION COMPLETE"
echo "=========================================="
echo ""
print_info "Infrastructure has been destroyed."
echo ""
echo "Remaining manual cleanup (if needed):"
echo "1. Check AWS Console for any remaining resources"
echo "2. Review CloudWatch Logs for any retained log groups"
echo "3. Check S3 for any remaining buckets"
echo "4. Review IAM for any orphaned roles/policies"
echo ""

# Check if .env should be removed
read -p "Do you want to remove the .env file? (yes/no): " REMOVE_ENV
if [ "$REMOVE_ENV" == "yes" ]; then
    rm -f .env
    print_info ".env file removed"
else
    print_info ".env file preserved"
fi

echo ""
print_info "Destruction script completed."
