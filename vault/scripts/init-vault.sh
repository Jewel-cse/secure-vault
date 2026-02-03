#!/bin/bash
# Vault Production Initialization Script
# Run this script ONCE after starting Vault for the first time

set -e

echo "=========================================="
echo "Vault Production Initialization"
echo "=========================================="

# Wait for Vault to be ready
echo "Waiting for Vault to start..."
sleep 5

# Initialize Vault (only run once!)
echo "Initializing Vault..."
docker exec vault-prod vault operator init -key-shares=5 -key-threshold=3 > vault-keys.txt

echo ""
echo "✅ Vault initialized!"
echo "⚠️  IMPORTANT: vault-keys.txt contains your unseal keys and root token"
echo "⚠️  Store this file securely and NEVER commit it to git!"
echo ""

# Extract unseal keys and root token
UNSEAL_KEY_1=$(grep 'Unseal Key 1:' vault-keys.txt | awk '{print $NF}')
UNSEAL_KEY_2=$(grep 'Unseal Key 2:' vault-keys.txt | awk '{print $NF}')
UNSEAL_KEY_3=$(grep 'Unseal Key 3:' vault-keys.txt | awk '{print $NF}')
ROOT_TOKEN=$(grep 'Initial Root Token:' vault-keys.txt | awk '{print $NF}')

# Unseal Vault (requires 3 of 5 keys)
echo "Unsealing Vault..."
docker exec vault-prod vault operator unseal "$UNSEAL_KEY_1"
docker exec vault-prod vault operator unseal "$UNSEAL_KEY_2"
docker exec vault-prod vault operator unseal "$UNSEAL_KEY_3"

echo ""
echo "✅ Vault unsealed!"
echo ""

# Login with root token
echo "Logging in with root token..."
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault-prod vault login "$ROOT_TOKEN"

# Enable KV v2 secrets engine
echo "Enabling KV v2 secrets engine..."
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault-prod vault secrets enable -path=secret kv-v2

# Enable AppRole authentication
echo "Enabling AppRole authentication..."
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault-prod vault auth enable approle

# Create policy for payment-service
echo "Creating payment-service policy..."
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault-prod vault policy write payment-service /vault/policies/payment-service-policy.hcl

# Create AppRole for payment-service
echo "Creating AppRole for payment-service..."
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault-prod vault write auth/approle/role/payment-service \
    token_policies="payment-service" \
    token_ttl=1h \
    token_max_ttl=4h \
    secret_id_ttl=0

# Get Role ID
echo "Getting Role ID..."
ROLE_ID=$(docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault-prod vault read -field=role_id auth/approle/role/payment-service/role-id)

# Generate Secret ID
echo "Generating Secret ID..."
SECRET_ID=$(docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault-prod vault write -field=secret_id -f auth/approle/role/payment-service/secret-id)

# Store credentials
cat > vault-approle-credentials.txt <<EOF
Payment Service AppRole Credentials
====================================
Role ID: $ROLE_ID
Secret ID: $SECRET_ID

⚠️  Store these securely!
⚠️  Add to environment variables or secret management system
⚠️  NEVER commit to git!
EOF

echo ""
echo "✅ AppRole created successfully!"
echo "✅ Credentials saved to vault-approle-credentials.txt"
echo ""

# Store sample secrets
echo "Storing sample secrets..."
docker exec -e VAULT_TOKEN="$ROOT_TOKEN" vault-prod vault kv put secret/payment-service \
    payment.apiKey="sk_prod_sample_key" \
    payment.merchantId="merchant_prod_123" \
    payment.webhookSecret="whsec_prod_secret"

echo ""
echo "=========================================="
echo "✅ Vault Production Setup Complete!"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Securely store vault-keys.txt (contains unseal keys and root token)"
echo "2. Add Role ID and Secret ID to your application's environment variables"
echo "3. Update application-prod.yml with AppRole authentication"
echo "4. Test the connection with: mvn spring-boot:run -Dspring.profiles.active=prod"
echo ""
echo "⚠️  SECURITY REMINDERS:"
echo "   - Add vault-keys.txt to .gitignore"
echo "   - Add vault-approle-credentials.txt to .gitignore"
echo "   - Store unseal keys in separate secure locations"
echo "   - Rotate Secret ID regularly"
echo ""
