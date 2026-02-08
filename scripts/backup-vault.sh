#!/bin/bash
# Vault Backup Script
# Creates encrypted backup of Vault data from S3

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="vault-backup-$TIMESTAMP"
S3_BUCKET="${S3_BUCKET_NAME:-vault-production-storage}"
BACKUP_S3_BUCKET="${BACKUP_S3_BUCKET:-vault-backups}"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo -e "${GREEN}📦 Vault Backup Script${NC}"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Step 1: Sync S3 data to local
echo -e "${YELLOW}Step 1: Downloading Vault data from S3...${NC}"
aws s3 sync "s3://$S3_BUCKET/vault/" "$BACKUP_DIR/$BACKUP_NAME/s3-data/" --region "$AWS_REGION"

echo -e "${GREEN}✅ S3 data downloaded${NC}"

# Step 2: Export policies
echo -e "${YELLOW}Step 2: Exporting policies...${NC}"
mkdir -p "$BACKUP_DIR/$BACKUP_NAME/policies"

if [ -n "$VAULT_TOKEN" ]; then
    vault policy list | while read -r policy; do
        if [ "$policy" != "default" ] && [ "$policy" != "root" ]; then
            vault policy read "$policy" > "$BACKUP_DIR/$BACKUP_NAME/policies/$policy.hcl" 2>/dev/null || true
        fi
    done
    echo -e "${GREEN}✅ Policies exported${NC}"
else
    echo -e "${YELLOW}⚠️  VAULT_TOKEN not set. Skipping policy export.${NC}"
fi

# Step 3: Create metadata file
echo -e "${YELLOW}Step 3: Creating backup metadata...${NC}"
cat > "$BACKUP_DIR/$BACKUP_NAME/metadata.json" <<EOF
{
  "backup_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "s3_bucket": "$S3_BUCKET",
  "aws_region": "$AWS_REGION",
  "vault_version": "$(vault version | head -n1 || echo 'unknown')"
}
EOF

echo -e "${GREEN}✅ Metadata created${NC}"

# Step 4: Create tarball
echo -e "${YELLOW}Step 4: Creating compressed archive...${NC}"
cd "$BACKUP_DIR"
tar -czf "$BACKUP_NAME.tar.gz" "$BACKUP_NAME/"
cd - > /dev/null

echo -e "${GREEN}✅ Archive created: $BACKUP_DIR/$BACKUP_NAME.tar.gz${NC}"

# Step 5: Encrypt backup (optional but recommended)
if command -v gpg &> /dev/null; then
    echo -e "${YELLOW}Step 5: Encrypting backup with GPG...${NC}"
    echo "Enter encryption passphrase:"
    gpg --symmetric --cipher-algo AES256 "$BACKUP_DIR/$BACKUP_NAME.tar.gz"
    rm -f "$BACKUP_DIR/$BACKUP_NAME.tar.gz"
    echo -e "${GREEN}✅ Backup encrypted: $BACKUP_DIR/$BACKUP_NAME.tar.gz.gpg${NC}"
    FINAL_BACKUP="$BACKUP_DIR/$BACKUP_NAME.tar.gz.gpg"
else
    echo -e "${YELLOW}⚠️  GPG not found. Backup not encrypted.${NC}"
    FINAL_BACKUP="$BACKUP_DIR/$BACKUP_NAME.tar.gz"
fi

# Step 6: Upload to backup S3 bucket
echo -e "${YELLOW}Step 6: Uploading to backup S3 bucket...${NC}"
aws s3 cp "$FINAL_BACKUP" "s3://$BACKUP_S3_BUCKET/" --region "$AWS_REGION"

echo -e "${GREEN}✅ Backup uploaded to S3${NC}"

# Cleanup local temporary data
rm -rf "$BACKUP_DIR/$BACKUP_NAME"

# Summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}🎉 Backup complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Local backup: $FINAL_BACKUP"
echo "S3 backup: s3://$BACKUP_S3_BUCKET/$(basename $FINAL_BACKUP)"
echo "Backup size: $(du -h "$FINAL_BACKUP" | cut -f1)"
echo ""
echo -e "${YELLOW}⚠️  Store the encryption passphrase securely!${NC}"
echo ""
