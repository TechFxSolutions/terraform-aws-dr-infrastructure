# Fix: prevent_destroy Error When Destroying Infrastructure

If you get the error "Resource has lifecycle.prevent_destroy set" when running `destroy-all.sh`, here's how to fix it.

## 🔍 Understanding the Error

```
Error: Instance cannot be destroyed

Resource aws_s3_bucket.terraform_state has lifecycle.prevent_destroy set,
but the plan calls for this resource to be destroyed.
```

**Why this happens:**
- The S3 backend has `prevent_destroy = true` to protect your Terraform state
- This is a safety feature to prevent accidental deletion
- You need to explicitly bypass this protection to destroy the backend

---

## 🛠️ Solution Options

### Option 1: Use Updated destroy-all.sh (Recommended)

The updated script handles this automatically:

```bash
# Pull latest changes
git pull origin main

# Make executable
chmod +x scripts/destroy-all.sh

# Run destroy
./scripts/destroy-all.sh
```

The script will:
1. Destroy secondary region
2. Destroy primary region
3. Destroy global IAM
4. Ask if you want to destroy S3 backend
5. Automatically handle prevent_destroy protection

---

### Option 2: Use Force Destroy Script

If the main script fails, use the force destroy script:

```bash
# Make executable
chmod +x scripts/force-destroy-backend.sh

# Run force destroy
./scripts/force-destroy-backend.sh
```

This script:
- Empties the S3 bucket
- Removes prevent_destroy from config
- Destroys resources
- Cleans up local state

---

### Option 3: Manual Fix (Step-by-Step)

If you prefer to do it manually:

#### Step 1: Destroy Everything Except Backend

```bash
# Destroy secondary region
cd environments/secondary
terraform destroy -auto-approve

# Destroy primary region
cd ../primary
terraform destroy -auto-approve

# Destroy global IAM
cd ../../global/iam
terraform destroy -auto-approve
```

#### Step 2: Empty S3 Bucket

```bash
cd ../s3-backend

# Get bucket name
BUCKET=$(terraform output -raw s3_bucket_name)

# Empty bucket
aws s3 rm s3://$BUCKET --recursive

# Delete all versions
aws s3api list-object-versions \
    --bucket $BUCKET \
    --output json | \
    jq -r '.Versions[]? | "--key \"\(.Key)\" --version-id \(.VersionId)"' | \
    xargs -I {} aws s3api delete-object --bucket $BUCKET {}

# Delete all delete markers
aws s3api list-object-versions \
    --bucket $BUCKET \
    --output json | \
    jq -r '.DeleteMarkers[]? | "--key \"\(.Key)\" --version-id \(.VersionId)"' | \
    xargs -I {} aws s3api delete-object --bucket $BUCKET {}
```

#### Step 3: Edit main.tf

```bash
# Open main.tf
nano global/s3-backend/main.tf
```

**Find and remove these blocks:**

```hcl
# Remove this from aws_s3_bucket resource
lifecycle {
  prevent_destroy = true
}

# Remove this from aws_dynamodb_table resource
lifecycle {
  prevent_destroy = true
}
```

**Or use sed:**

```bash
cd global/s3-backend
sed -i.backup '/lifecycle {/,/}/d' main.tf
```

#### Step 4: Destroy Backend

```bash
cd global/s3-backend
terraform destroy -auto-approve
```

#### Step 5: Clean Up

```bash
cd ../../
rm -rf .terraform
rm -f terraform.tfstate*
rm -f .terraform.lock.hcl
```

---

## 🚨 Quick Fix Commands

### One-Liner to Remove prevent_destroy

```bash
cd global/s3-backend && \
sed -i.backup '/lifecycle {/,/}/d' main.tf && \
terraform destroy -auto-approve
```

### Complete Cleanup Script

```bash
#!/bin/bash
# Quick cleanup

# Get bucket name
cd global/s3-backend
BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null)

# Empty bucket
if [ -n "$BUCKET" ]; then
    aws s3 rm s3://$BUCKET --recursive
    aws s3api list-object-versions --bucket $BUCKET --output json | \
        jq -r '.Versions[]? | "--key \"\(.Key)\" --version-id \(.VersionId)"' | \
        xargs -I {} aws s3api delete-object --bucket $BUCKET {}
fi

# Remove prevent_destroy
sed -i.backup '/lifecycle {/,/}/d' main.tf

# Destroy
terraform destroy -auto-approve

# Cleanup
rm -rf .terraform terraform.tfstate* .terraform.lock.hcl
```

---

## 🔧 Alternative: Manual AWS Console Deletion

If Terraform fails completely:

### Delete S3 Bucket

1. Go to AWS Console → S3
2. Find bucket: `terraform-dr-infrastructure-state-*`
3. Click "Empty" button
4. Confirm deletion of all objects
5. Click "Delete" button
6. Confirm bucket deletion

### Delete DynamoDB Table

1. Go to AWS Console → DynamoDB
2. Find table: `terraform-dr-infrastructure-locks`
3. Click "Delete"
4. Confirm deletion

### Clean Local State

```bash
cd global/s3-backend
rm -rf .terraform terraform.tfstate* .terraform.lock.hcl
```

---

## 📋 Verification

After destruction, verify resources are gone:

```bash
# Check S3 buckets
aws s3 ls | grep terraform

# Check DynamoDB tables
aws dynamodb list-tables | grep terraform

# Should return nothing
```

---

## 🛡️ Why prevent_destroy Exists

The `prevent_destroy` lifecycle rule is there to protect you from:
- Accidentally destroying your Terraform state
- Losing infrastructure state data
- Breaking your ability to manage infrastructure

**Best Practice:**
- Only remove it when you're 100% sure you want to destroy everything
- Always backup state files before destroying
- Consider exporting state: `terraform state pull > backup.tfstate`

---

## 💡 Tips

### Backup State Before Destroying

```bash
# Backup all state files
cd global/s3-backend
terraform state pull > state-backup-$(date +%Y%m%d).tfstate

cd ../../environments/primary
terraform state pull > state-backup-$(date +%Y%m%d).tfstate

cd ../secondary
terraform state pull > state-backup-$(date +%Y%m%d).tfstate
```

### Selective Destruction

If you only want to destroy specific resources:

```bash
# Destroy only specific resource
terraform destroy -target=aws_instance.web

# Destroy everything except backend
terraform destroy -target=module.networking -target=module.compute
```

### Check What Will Be Destroyed

```bash
# See destruction plan without executing
terraform plan -destroy
```

---

## 🆘 Still Having Issues?

### Error: Bucket Not Empty

```bash
# Force empty bucket
BUCKET=your-bucket-name
aws s3 rb s3://$BUCKET --force
```

### Error: Table Being Deleted

```bash
# Wait for table deletion to complete
aws dynamodb wait table-not-exists --table-name your-table-name
```

### Error: Access Denied

```bash
# Check IAM permissions
aws iam get-user
aws iam list-attached-user-policies --user-name YOUR_USERNAME

# You need these permissions:
# - s3:DeleteBucket
# - s3:DeleteObject
# - dynamodb:DeleteTable
```

---

## 📞 Need Help?

1. **Use force destroy script**: `./scripts/force-destroy-backend.sh`
2. **Check logs**: Look for specific error messages
3. **Manual cleanup**: Use AWS Console as last resort
4. **Open issue**: Include error messages and steps tried

---

## ✅ Summary

**Quick Fix:**
```bash
# Option 1: Use updated script
./scripts/destroy-all.sh

# Option 2: Use force destroy
./scripts/force-destroy-backend.sh

# Option 3: Manual fix
cd global/s3-backend
sed -i '/lifecycle {/,/}/d' main.tf
terraform destroy -auto-approve
```

**The error is expected and is a safety feature. The updated scripts handle it automatically!**

---

**Last Updated**: December 11, 2025
