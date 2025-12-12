#!/bin/bash
# Make all scripts executable
# Run this once after cloning the repository

chmod +x scripts/deploy-all.sh
chmod +x scripts/validate-deployment.sh
chmod +x scripts/destroy-all.sh

echo "✓ All scripts are now executable"
echo ""
echo "You can now run:"
echo "  ./scripts/deploy-all.sh"
echo "  ./scripts/validate-deployment.sh"
echo "  ./scripts/destroy-all.sh"
