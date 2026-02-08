#!/bin/bash
# Vault Initialization Script for Production
# Initializes Vault cluster and saves unseal keys securely

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

VAULT_ADDR="${VAULT_ADDR:-https://localhost:443}"
VAULT_SKIP_VERIFY="${VAULT_SKIP_VERIFY:-true}"

echo -e "${GREEN}🔐 Vault Production Initialization${NC}"
echo ""

# Check if Vault is already initialized
echo -e "${YELLOW}Checking Vault status...${NC}"
if vault status 2>/dev/null | grep -q "Initialized.*true"; then
    echo -e "${RED}❌ Vault is already initialized!${NC}"
    echo "If you need to re-initialize, you must first delete all data from S3."
    exit 1
fi

echo -e "${GREEN}✅ Vault is not initialized. Proceeding...${NC}"
echo ""

# Initialize Vault
echo -e "${YELLOW}Initializing Vault with Shamir's Secret Sharing...${NC}"
echo "Key Shares: 5"
echo "Key Threshold: 3"
echo ""

INIT_OUTPUT=$(vault operator init \
    -key-shares=5 \
    -key-threshold=3 \
    -format=json)

# Extract keys and root token
UNSEAL_KEY_1=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[0]')
UNSEAL_KEY_2=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[1]')
UNSEAL_KEY_3=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[2]')
UNSEAL_KEY_4=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[3]')
UNSEAL_KEY_5=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[4]')
ROOT_TOKEN=$(echo "$INIT_OUTPUT" | jq -r '.root_token')

# Save to secure file
KEYS_FILE="./vault-keys-$(date +%Y%m%d-%H%M%S).txt"

cat > "$KEYS_FILE" <<EOF
========================================
VAULT INITIALIZATION KEYS
Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
========================================

⚠️  CRITICAL: Store these keys securely!
⚠️  You need 3 of 5 keys to unseal Vault
⚠️  If you lose these keys, you cannot unseal Vault!

UNSEAL KEYS
-----------
Unseal Key 1: $UNSEAL_KEY_1
Unseal Key 2: $UNSEAL_KEY_2
Unseal Key 3: $UNSEAL_KEY_3
Unseal Key 4: $UNSEAL_KEY_4
Unseal Key 5: $UNSEAL_KEY_5

ROOT TOKEN
----------
Root Token: $ROOT_TOKEN

⚠️  Revoke root token after initial setup!

UNSEALING VAULT
---------------
vault operator unseal $UNSEAL_KEY_1
vault operator unseal $UNSEAL_KEY_2
vault operator unseal $UNSEAL_KEY_3

LOGIN
-----
vault login $ROOT_TOKEN

========================================
EOF

chmod 600 "$KEYS_FILE"

echo -e "${GREEN}✅ Vault initialized successfully!${NC}"
echo -e "${GREEN}✅ Keys saved to: $KEYS_FILE${NC}"
echo ""

# Unseal Vault
echo -e "${YELLOW}Unsealing Vault...${NC}"
vault operator unseal "$UNSEAL_KEY_1"
vault operator unseal "$UNSEAL_KEY_2"
vault operator unseal "$UNSEAL_KEY_3"

echo -e "${GREEN}✅ Vault unsealed!${NC}"
echo ""

# Login with root token
echo -e "${YELLOW}Logging in with root token...${NC}"
export VAULT_TOKEN="$ROOT_TOKEN"
vault login "$ROOT_TOKEN" > /dev/null

echo -e "${GREEN}✅ Logged in successfully!${NC}"
echo ""

# Enable audit logging
echo -e "${YELLOW}Enabling audit logging...${NC}"
vault audit enable file file_path=/vault/logs/audit.log

echo -e "${GREEN}✅ Audit logging enabled${NC}"
echo ""

# Enable AppRole auth method
echo -e "${YELLOW}Enabling AppRole authentication...${NC}"
vault auth enable approle

echo -e "${GREEN}✅ AppRole enabled${NC}"
echo ""

# Enable KV v2 secrets engine
echo -e "${YELLOW}Enabling KV v2 secrets engine...${NC}"
vault secrets enable -path=secret kv-v2

echo -e "${GREEN}✅ KV v2 secrets engine enabled${NC}"
echo ""

# Create admin policy
echo -e "${YELLOW}Creating admin policy...${NC}"
vault policy write admin /vault/policies/admin-policy.hcl

echo -e "${GREEN}✅ Admin policy created${NC}"
echo ""

# Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}🎉 Vault initialization complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT NEXT STEPS:${NC}"
echo ""
echo "1. Distribute unseal keys to 5 different administrators"
echo "2. Store keys in secure locations (password managers, HSMs, etc.)"
echo "3. Delete this file after distributing keys: rm $KEYS_FILE"
echo "4. Create admin users and revoke root token"
echo "5. Setup client namespaces using: ./scripts/create-client.sh"
echo ""
echo -e "${RED}⚠️  DO NOT commit $KEYS_FILE to version control!${NC}"
echo ""
