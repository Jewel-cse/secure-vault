#!/bin/bash
# Create Client Namespace Script
# Provisions a new client with isolated secrets and AppRole authentication

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if client name is provided
if [ -z "$1" ]; then
    echo -e "${RED}❌ Error: Client name is required${NC}"
    echo "Usage: $0 <client-name> [admin-email]"
    echo "Example: $0 acme-corp admin@acme.com"
    exit 1
fi

CLIENT_NAME="$1"
ADMIN_EMAIL="${2:-}"

# Validate client name (alphanumeric and hyphens only)
if ! [[ "$CLIENT_NAME" =~ ^[a-z0-9-]+$ ]]; then
    echo -e "${RED}❌ Error: Client name must contain only lowercase letters, numbers, and hyphens${NC}"
    exit 1
fi

# Vault configuration
VAULT_ADDR="${VAULT_ADDR:-https://localhost:443}"
VAULT_TOKEN="${VAULT_TOKEN:-}"

if [ -z "$VAULT_TOKEN" ]; then
    echo -e "${YELLOW}⚠️  VAULT_TOKEN not set. Please provide root or admin token:${NC}"
    read -s VAULT_TOKEN
    export VAULT_TOKEN
fi

echo -e "${GREEN}🚀 Creating client namespace for: $CLIENT_NAME${NC}"
echo ""

# Step 1: Create client-specific policy
echo -e "${YELLOW}📝 Step 1: Creating client policy...${NC}"
POLICY_FILE="/tmp/${CLIENT_NAME}-policy.hcl"

cat > "$POLICY_FILE" <<EOF
# Client Policy for $CLIENT_NAME
# Read-only access to client-specific secrets

path "secret/data/${CLIENT_NAME}/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/${CLIENT_NAME}/*" {
  capabilities = ["list"]
}

path "database/creds/${CLIENT_NAME}-*" {
  capabilities = ["read"]
}

path "aws/creds/${CLIENT_NAME}-*" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "sys/health" {
  capabilities = ["read"]
}
EOF

vault policy write "${CLIENT_NAME}" "$POLICY_FILE"
rm -f "$POLICY_FILE"
echo -e "${GREEN}✅ Policy created: ${CLIENT_NAME}${NC}"

# Step 2: Create client admin policy
echo -e "${YELLOW}📝 Step 2: Creating client admin policy...${NC}"
ADMIN_POLICY_FILE="/tmp/${CLIENT_NAME}-admin-policy.hcl"

cat > "$ADMIN_POLICY_FILE" <<EOF
# Client Admin Policy for $CLIENT_NAME
# Full CRUD access to client-specific secrets

path "secret/data/${CLIENT_NAME}/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/${CLIENT_NAME}/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/delete/${CLIENT_NAME}/*" {
  capabilities = ["update"]
}

path "secret/undelete/${CLIENT_NAME}/*" {
  capabilities = ["update"]
}

path "secret/destroy/${CLIENT_NAME}/*" {
  capabilities = ["update"]
}

path "database/creds/${CLIENT_NAME}-*" {
  capabilities = ["read"]
}

path "auth/approle/role/${CLIENT_NAME}/secret-id" {
  capabilities = ["update", "list"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "sys/health" {
  capabilities = ["read"]
}
EOF

vault policy write "${CLIENT_NAME}-admin" "$ADMIN_POLICY_FILE"
rm -f "$ADMIN_POLICY_FILE"
echo -e "${GREEN}✅ Admin policy created: ${CLIENT_NAME}-admin${NC}"

# Step 3: Create AppRole for application
echo -e "${YELLOW}📝 Step 3: Creating AppRole for application...${NC}"
vault write auth/approle/role/"${CLIENT_NAME}" \
    token_ttl=1h \
    token_max_ttl=4h \
    token_policies="${CLIENT_NAME}" \
    bind_secret_id=true \
    secret_id_ttl=0 \
    secret_id_num_uses=0

echo -e "${GREEN}✅ AppRole created: ${CLIENT_NAME}${NC}"

# Step 4: Get Role ID
echo -e "${YELLOW}📝 Step 4: Retrieving Role ID...${NC}"
ROLE_ID=$(vault read -field=role_id auth/approle/role/"${CLIENT_NAME}"/role-id)
echo -e "${GREEN}✅ Role ID: ${ROLE_ID}${NC}"

# Step 5: Generate Secret ID
echo -e "${YELLOW}📝 Step 5: Generating Secret ID...${NC}"
SECRET_ID=$(vault write -field=secret_id -f auth/approle/role/"${CLIENT_NAME}"/secret-id)
echo -e "${GREEN}✅ Secret ID generated${NC}"

# Step 6: Create initial secret structure
echo -e "${YELLOW}📝 Step 6: Creating initial secret structure...${NC}"
vault kv put secret/"${CLIENT_NAME}"/config \
    environment="production" \
    created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    admin_email="${ADMIN_EMAIL}"

vault kv put secret/"${CLIENT_NAME}"/database \
    username="" \
    password="" \
    host="" \
    port="" \
    database="" \
    note="Update these values with actual database credentials"

vault kv put secret/"${CLIENT_NAME}"/api-keys \
    note="Add your API keys here"

echo -e "${GREEN}✅ Initial secret structure created${NC}"

# Step 7: Create credentials file
echo -e "${YELLOW}📝 Step 7: Generating credentials file...${NC}"
CREDS_FILE="./clients/${CLIENT_NAME}-credentials.txt"
mkdir -p ./clients

cat > "$CREDS_FILE" <<EOF
========================================
Client: $CLIENT_NAME
Created: $(date -u +%Y-%m-%dT%H:%M:%SZ)
========================================

VAULT CONFIGURATION
-------------------
Vault Address: $VAULT_ADDR
Client Name: $CLIENT_NAME

APPLICATION CREDENTIALS (AppRole)
---------------------------------
Role ID: $ROLE_ID
Secret ID: $SECRET_ID

⚠️  IMPORTANT: Keep these credentials secure!
⚠️  Secret ID is shown only once. Store it safely.

POLICIES
--------
- ${CLIENT_NAME}: Read-only access to secrets
- ${CLIENT_NAME}-admin: Full CRUD access to secrets

SECRET PATHS
------------
- secret/${CLIENT_NAME}/config
- secret/${CLIENT_NAME}/database
- secret/${CLIENT_NAME}/api-keys

USAGE EXAMPLE (Spring Boot)
----------------------------
spring:
  cloud:
    vault:
      uri: $VAULT_ADDR
      authentication: APPROLE
      app-role:
        role-id: $ROLE_ID
        secret-id: $SECRET_ID
        role: $CLIENT_NAME
      kv:
        enabled: true
        backend: secret
        application-name: $CLIENT_NAME

VAULT CLI COMMANDS
------------------
# Login with AppRole
vault write auth/approle/login role_id=$ROLE_ID secret_id=$SECRET_ID

# Read a secret
vault kv get secret/${CLIENT_NAME}/database

# Write a secret (requires admin policy)
vault kv put secret/${CLIENT_NAME}/api-keys stripe_key=sk_test_xxx

NEXT STEPS
----------
1. Share Role ID and Secret ID with the client securely
2. Update secret values in Vault
3. Configure client application to use Vault
4. Test authentication and secret retrieval
5. Rotate Secret ID after initial setup

========================================
EOF

chmod 600 "$CREDS_FILE"
echo -e "${GREEN}✅ Credentials saved to: $CREDS_FILE${NC}"

# Summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}🎉 Client provisioning complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Client Name: ${GREEN}$CLIENT_NAME${NC}"
echo -e "Policy: ${GREEN}${CLIENT_NAME}${NC}"
echo -e "Admin Policy: ${GREEN}${CLIENT_NAME}-admin${NC}"
echo -e "AppRole: ${GREEN}${CLIENT_NAME}${NC}"
echo -e "Credentials File: ${GREEN}$CREDS_FILE${NC}"
echo ""
echo -e "${YELLOW}⚠️  Next Steps:${NC}"
echo "1. Review and update secrets in: secret/$CLIENT_NAME/"
echo "2. Securely share credentials file with client"
echo "3. Delete credentials file after sharing: rm $CREDS_FILE"
echo "4. Rotate Secret ID after client confirms setup"
echo ""

# Optional: Send email if configured
if [ -n "$ADMIN_EMAIL" ]; then
    echo -e "${YELLOW}📧 Admin email recorded: $ADMIN_EMAIL${NC}"
fi
