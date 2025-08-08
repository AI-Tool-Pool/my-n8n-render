#!/bin/bash
# Test script to run with minimal workflows for faster startup

echo "Creating minimal workflow test..."

# Backup original workflows
mkdir -p workflows-backup
cp workflows/*.json workflows-backup/

# Keep only essential small workflows for testing
cd workflows
ls -la *.json | head -5 | awk '{print $9}' > ../keep-workflows.txt

# Remove all workflows temporarily
rm *.json

# Restore only the small ones
while read workflow; do
    if [ -f "../workflows-backup/$workflow" ]; then
        cp "../workflows-backup/$workflow" .
    fi
done < ../keep-workflows.txt

echo "Minimal workflows ready. Run docker test again."
echo "To restore all workflows: cp workflows-backup/*.json workflows/"
