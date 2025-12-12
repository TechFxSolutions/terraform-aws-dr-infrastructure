#!/bin/bash
# Test AWS Credentials Setup
# This script helps diagnose credential issues

set +e  # Don't exit on errors

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

print_fail() {
    echo -e "${RED}✗${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

echo "=========================================="
echo "  AWS Credentials Diagnostic Tool"
echo "=========================================="
echo ""

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# Step 1: Check if .env file exists
print_info "Step 1: Checking if .env file exists..."
if [ -f ".env" ]; then
    print_pass ".env file exists"
    
    # Check file permissions
    PERMS=$(stat -c "%a" .env 2>/dev/null || stat -f "%A" .env 2>/dev/null)
    print_info "File permissions: $PERMS"
    
    # Check file size
    SIZE=$(wc -c < .env)
    if [ "$SIZE" -gt 0 ]; then
        print_pass ".env file is not empty ($SIZE bytes)"
    else
        print_fail ".env file is empty!"
        echo ""
        echo "Fix: Add your AWS credentials to .env file"
        echo "Example:"
        echo "  AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE"
        echo "  AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
        echo "  AWS_DEFAULT_REGION=us-east-1"
        exit 1
    fi
else
    print_fail ".env file does not exist!"
    echo ""
    echo "Fix: Create .env file from template"
    echo "  cp .env.example .env"
    echo "  nano .env  # Add your credentials"
    exit 1
fi

echo ""

# Step 2: Check .env file content
print_info "Step 2: Checking .env file content..."

# Check for AWS_ACCESS_KEY_ID
if grep -q "^AWS_ACCESS_KEY_ID=" .env; then
    VALUE=$(grep "^AWS_ACCESS_KEY_ID=" .env | cut -d'=' -f2)
    if [ -n "$VALUE" ] && [ "$VALUE" != "your_access_key_here" ]; then
        print_pass "AWS_ACCESS_KEY_ID is set (${VALUE:0:10}...)"
    else
        print_fail "AWS_ACCESS_KEY_ID is not configured (still has placeholder value)"
        echo "  Fix: Edit .env and replace 'your_access_key_here' with your actual access key"
    fi
else
    print_fail "AWS_ACCESS_KEY_ID not found in .env"
    echo "  Fix: Add 'AWS_ACCESS_KEY_ID=your_key' to .env"
fi

# Check for AWS_SECRET_ACCESS_KEY
if grep -q "^AWS_SECRET_ACCESS_KEY=" .env; then
    VALUE=$(grep "^AWS_SECRET_ACCESS_KEY=" .env | cut -d'=' -f2)
    if [ -n "$VALUE" ] && [ "$VALUE" != "your_secret_key_here" ]; then
        print_pass "AWS_SECRET_ACCESS_KEY is set (${VALUE:0:10}...)"
    else
        print_fail "AWS_SECRET_ACCESS_KEY is not configured (still has placeholder value)"
        echo "  Fix: Edit .env and replace 'your_secret_key_here' with your actual secret key"
    fi
else
    print_fail "AWS_SECRET_ACCESS_KEY not found in .env"
    echo "  Fix: Add 'AWS_SECRET_ACCESS_KEY=your_secret' to .env"
fi

# Check for AWS_DEFAULT_REGION
if grep -q "^AWS_DEFAULT_REGION=" .env; then
    VALUE=$(grep "^AWS_DEFAULT_REGION=" .env | cut -d'=' -f2)
    if [ -n "$VALUE" ]; then
        print_pass "AWS_DEFAULT_REGION is set ($VALUE)"
    else
        print_warn "AWS_DEFAULT_REGION is empty (will default to us-east-1)"
    fi
else
    print_warn "AWS_DEFAULT_REGION not found in .env (will default to us-east-1)"
fi

echo ""

# Step 3: Load .env and check environment variables
print_info "Step 3: Loading .env file..."

set -a
source .env 2>/dev/null
set +a

if [ -n "$AWS_ACCESS_KEY_ID" ]; then
    print_pass "AWS_ACCESS_KEY_ID loaded into environment"
else
    print_fail "AWS_ACCESS_KEY_ID not loaded into environment"
fi

if [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
    print_pass "AWS_SECRET_ACCESS_KEY loaded into environment"
else
    print_fail "AWS_SECRET_ACCESS_KEY not loaded into environment"
fi

if [ -n "$AWS_DEFAULT_REGION" ]; then
    print_pass "AWS_DEFAULT_REGION loaded into environment ($AWS_DEFAULT_REGION)"
else
    print_warn "AWS_DEFAULT_REGION not set (using default)"
fi

echo ""

# Step 4: Test AWS CLI
print_info "Step 4: Testing AWS CLI..."

if command -v aws >/dev/null 2>&1; then
    print_pass "AWS CLI is installed"
    
    AWS_VERSION=$(aws --version 2>&1)
    print_info "Version: $AWS_VERSION"
    
    echo ""
    print_info "Testing AWS credentials..."
    
    if aws sts get-caller-identity >/dev/null 2>&1; then
        print_pass "AWS credentials are valid!"
        echo ""
        echo "Credential Details:"
        aws sts get-caller-identity
        echo ""
        print_pass "SUCCESS! Your AWS credentials are working correctly."
    else
        print_fail "AWS credentials test failed!"
        echo ""
        echo "Error details:"
        aws sts get-caller-identity 2>&1
        echo ""
        echo "Common causes:"
        echo "  1. Invalid access key or secret key"
        echo "  2. Credentials have been deactivated in AWS Console"
        echo "  3. Network/firewall blocking AWS API calls"
        echo "  4. Incorrect region configuration"
        echo ""
        echo "Fix:"
        echo "  1. Verify credentials in AWS Console (IAM → Users → Security credentials)"
        echo "  2. Generate new access key if needed"
        echo "  3. Update .env file with correct credentials"
    fi
else
    print_fail "AWS CLI is not installed!"
    echo ""
    echo "Install AWS CLI:"
    echo "  macOS: brew install awscli"
    echo "  Linux: sudo apt-get install awscli"
    echo "  Windows: Download from https://aws.amazon.com/cli/"
fi

echo ""

# Step 5: Show .env file content (masked)
print_info "Step 5: Current .env configuration (sensitive values masked)..."
echo ""

if [ -f ".env" ]; then
    while IFS= read -r line; do
        # Skip empty lines and comments
        if [[ -z "$line" ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
            echo "$line"
        elif [[ "$line" =~ ^AWS_ACCESS_KEY_ID= ]]; then
            VALUE=$(echo "$line" | cut -d'=' -f2)
            if [ ${#VALUE} -gt 10 ]; then
                echo "AWS_ACCESS_KEY_ID=${VALUE:0:10}...${VALUE: -4}"
            else
                echo "$line"
            fi
        elif [[ "$line" =~ ^AWS_SECRET_ACCESS_KEY= ]]; then
            VALUE=$(echo "$line" | cut -d'=' -f2)
            if [ ${#VALUE} -gt 10 ]; then
                echo "AWS_SECRET_ACCESS_KEY=${VALUE:0:10}...${VALUE: -4}"
            else
                echo "$line"
            fi
        else
            echo "$line"
        fi
    done < .env
else
    print_fail ".env file not found"
fi

echo ""
echo "=========================================="
echo "  Diagnostic Complete"
echo "=========================================="
echo ""

# Final recommendations
if aws sts get-caller-identity >/dev/null 2>&1; then
    echo -e "${GREEN}✓ All checks passed! You can now run deployment scripts.${NC}"
    echo ""
    echo "Next steps:"
    echo "  ./scripts/deploy-all.sh"
else
    echo -e "${RED}✗ Credentials are not working. Please fix the issues above.${NC}"
    echo ""
    echo "Quick fix steps:"
    echo "  1. Edit .env file: nano .env"
    echo "  2. Replace placeholder values with your actual AWS credentials"
    echo "  3. Save and run this test again: ./scripts/test-credentials.sh"
    echo ""
    echo "Need help getting AWS credentials?"
    echo "  See: docs/ENV_FILE_SETUP.md"
fi

echo ""
