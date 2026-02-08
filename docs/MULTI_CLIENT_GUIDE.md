# Multi-Client Secret Management Guide

This guide explains how to manage secrets for multiple client projects using HashiCorp Vault with path-based isolation.

---

## Architecture Overview

### Client Isolation Strategy

Since we're using Vault OSS (not Enterprise), we achieve multi-client isolation through:

1. **Path-based separation**: Each client gets a dedicated path (e.g., `secret/client1/`, `secret/client2/`)
2. **Policy-based access control**: Strict policies prevent cross-client access
3. **Dedicated AppRoles**: Each client has their own AppRole for authentication
4. **Audit logging**: Track all access per client

```
secret/
├── client1/
│   ├── config
│   ├── database
│   └── api-keys
├── client2/
│   ├── config
│   ├── database
│   └── api-keys
└── client20/
    ├── config
    ├── database
    └── api-keys
```

---

## Client Onboarding

### Step 1: Provision New Client

**Automated (Recommended):**

```bash
# Linux/Ubuntu
./scripts/create-client.sh acme-corp admin@acme.com

# Windows
scripts\create-client.bat acme-corp admin@acme.com
```

**What this creates:**
- ✅ Read-only policy: `acme-corp`
- ✅ Admin policy: `acme-corp-admin`
- ✅ AppRole: `acme-corp`
- ✅ Initial secret structure
- ✅ Credentials file: `./clients/acme-corp-credentials.txt`

### Step 2: Configure Client Secrets

```bash
export VAULT_ADDR=https://localhost:443
export VAULT_TOKEN=<admin-token>

# Database credentials
vault kv put secret/acme-corp/database \
    username=acme_db_user \
    password=SecurePassword123! \
    host=db.acme.com \
    port=5432 \
    database=acme_production

# API Keys
vault kv put secret/acme-corp/api-keys \
    stripe_key=sk_live_xxxxxxxxxxxxx \
    sendgrid_key=SG.xxxxxxxxxxxxx \
    aws_access_key=AKIA xxxxxxxxxxxxx \
    aws_secret_key=xxxxxxxxxxxxx

# Application Config
vault kv put secret/acme-corp/config \
    environment=production \
    app_url=https://acme.com \
    admin_email=admin@acme.com \
    max_connections=100
```

### Step 3: Share Credentials

```bash
# Securely send credentials file to client
# Options:
# 1. Encrypted email
# 2. Secure file sharing (Dropbox, Google Drive with encryption)
# 3. Password manager (1Password, LastPass)

# After sharing, delete the file
rm ./clients/acme-corp-credentials.txt
```

---

## Managing 20 Clients

### Bulk Client Creation

Create a script to provision multiple clients:

```bash
#!/bin/bash
# bulk-create-clients.sh

CLIENTS=(
    "client1:admin@client1.com"
    "client2:admin@client2.com"
    "client3:admin@client3.com"
    # ... add all 20 clients
)

for client_info in "${CLIENTS[@]}"; do
    IFS=':' read -r client_name admin_email <<< "$client_info"
    echo "Creating client: $client_name"
    ./scripts/create-client.sh "$client_name" "$admin_email"
    sleep 2
done
```

### Client Naming Convention

Recommended naming patterns:
- **Company name**: `acme-corp`, `widgets-inc`
- **Project code**: `proj-alpha`, `proj-beta`
- **Department**: `finance-dept`, `hr-dept`

**Rules:**
- Lowercase only
- Use hyphens, not underscores
- No spaces or special characters
- Keep it short and memorable

---

## Secret Organization

### Recommended Structure

```
secret/<client-name>/
├── config/              # Application configuration
│   ├── environment
│   ├── app_url
│   └── feature_flags
├── database/            # Database credentials
│   ├── primary
│   ├── replica
│   └── analytics
├── api-keys/            # External service keys
│   ├── stripe
│   ├── sendgrid
│   └── aws
├── oauth/               # OAuth credentials
│   ├── google
│   ├── facebook
│   └── github
└── certificates/        # SSL/TLS certificates
    ├── private_key
    └── certificate
```

### Best Practices

1. **Use descriptive keys**: `stripe_secret_key` not `sk`
2. **Version secrets**: Use KV v2 for automatic versioning
3. **Document secrets**: Add `note` or `description` fields
4. **Rotate regularly**: Update secrets every 90 days
5. **Audit access**: Review audit logs monthly

---

## Access Control

### Policy Types

#### 1. Read-Only Policy (Application)

```hcl
# For production applications
path "secret/data/acme-corp/*" {
  capabilities = ["read", "list"]
}
```

#### 2. Admin Policy (Client Administrators)

```hcl
# For client admins to manage their secrets
path "secret/data/acme-corp/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
```

#### 3. Super Admin Policy (Vault Operators)

```hcl
# For Vault administrators
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
```

### Creating Custom Policies

```bash
# Create policy file
cat > client-custom-policy.hcl <<EOF
# Custom policy for acme-corp
path "secret/data/acme-corp/*" {
  capabilities = ["read"]
}

# Allow write to specific path
path "secret/data/acme-corp/temp/*" {
  capabilities = ["create", "update"]
}
EOF

# Apply policy
vault policy write acme-corp-custom client-custom-policy.hcl
```

---

## Client Authentication

### AppRole Authentication

Each client uses AppRole with:
- **Role ID**: Public identifier (can be in config files)
- **Secret ID**: Private credential (must be secured)

#### Rotating Secret IDs

```bash
# Generate new Secret ID
NEW_SECRET_ID=$(vault write -field=secret_id -f \
    auth/approle/role/acme-corp/secret-id)

# Share with client
echo "New Secret ID: $NEW_SECRET_ID"

# Client updates their application config
# Old Secret ID remains valid until revoked
```

#### Revoking Secret IDs

```bash
# List all Secret IDs
vault list auth/approle/role/acme-corp/secret-id

# Revoke specific Secret ID
vault write auth/approle/role/acme-corp/secret-id-accessor/destroy \
    secret_id_accessor=<accessor-id>
```

---

## Monitoring Client Access

### Audit Logs

```bash
# View all access by client
docker exec vault-prod-1 grep "acme-corp" /vault/logs/audit.log

# Count requests per client
docker exec vault-prod-1 grep -c "client1" /vault/logs/audit.log
docker exec vault-prod-1 grep -c "client2" /vault/logs/audit.log

# Find failed authentication attempts
docker exec vault-prod-1 grep "permission denied" /vault/logs/audit.log | grep "acme-corp"
```

### Metrics per Client

Create Grafana dashboard with:
- Request rate per client
- Authentication failures
- Secret access patterns
- Token TTL usage

---

## Client Offboarding

### Step 1: Backup Client Secrets

```bash
# Export all secrets
vault kv get -format=json secret/acme-corp/config > acme-corp-backup.json
vault kv get -format=json secret/acme-corp/database >> acme-corp-backup.json
vault kv get -format=json secret/acme-corp/api-keys >> acme-corp-backup.json

# Encrypt backup
gpg --symmetric --cipher-algo AES256 acme-corp-backup.json
```

### Step 2: Revoke Access

```bash
# Disable AppRole
vault delete auth/approle/role/acme-corp

# Delete policies
vault policy delete acme-corp
vault policy delete acme-corp-admin

# Revoke all tokens for this client
vault list auth/token/accessors | while read accessor; do
    vault token revoke -accessor $accessor 2>/dev/null || true
done
```

### Step 3: Archive or Delete Secrets

```bash
# Option 1: Archive (soft delete)
vault kv metadata put secret/acme-corp \
    custom_metadata=archived=true \
    custom_metadata=archived_date=$(date -u +%Y-%m-%d)

# Option 2: Delete (can be recovered)
vault kv delete secret/acme-corp/config
vault kv delete secret/acme-corp/database
vault kv delete secret/acme-corp/api-keys

# Option 3: Destroy permanently (cannot be recovered)
vault kv destroy -versions=1,2,3 secret/acme-corp/config
```

---

## Common Operations

### Update Secret

```bash
# Update single field
vault kv patch secret/acme-corp/database password=NewPassword123!

# Update entire secret
vault kv put secret/acme-corp/database \
    username=new_user \
    password=NewPassword123! \
    host=new-db.acme.com \
    port=5432
```

### View Secret History

```bash
# List versions
vault kv metadata get secret/acme-corp/database

# Read specific version
vault kv get -version=2 secret/acme-corp/database

# Rollback to previous version
vault kv rollback -version=2 secret/acme-corp/database
```

### Copy Secrets Between Clients

```bash
# Export from client1
vault kv get -format=json secret/client1/config > temp.json

# Import to client2
cat temp.json | jq -r '.data.data' | \
    vault kv put secret/client2/config -

# Clean up
rm temp.json
```

---

## Troubleshooting

### Client Cannot Access Secrets

```bash
# 1. Verify policy
vault policy read acme-corp

# 2. Check AppRole configuration
vault read auth/approle/role/acme-corp

# 3. Test authentication
vault write auth/approle/login \
    role_id=<role-id> \
    secret_id=<secret-id>

# 4. Check audit logs
docker exec vault-prod-1 tail -100 /vault/logs/audit.log | grep acme-corp
```

### Secret Not Found

```bash
# List all secrets for client
vault kv list secret/acme-corp

# Check if secret exists
vault kv get secret/acme-corp/database

# Check metadata
vault kv metadata get secret/acme-corp/database
```

### Permission Denied

```bash
# Verify token capabilities
vault token capabilities secret/acme-corp/database

# Check policy attachment
vault token lookup

# Update policy if needed
vault policy write acme-corp /vault/policies/client-template-policy.hcl
```

---

## Client Management Dashboard

### Create Overview Script

```bash
#!/bin/bash
# client-overview.sh

echo "=== Vault Client Overview ==="
echo ""

for client in $(vault list -format=json secret/ | jq -r '.[]'); do
    echo "Client: $client"
    echo "  Secrets: $(vault kv list secret/$client | wc -l)"
    echo "  Policy: $(vault policy read $client &>/dev/null && echo "✓" || echo "✗")"
    echo "  AppRole: $(vault read auth/approle/role/$client &>/dev/null && echo "✓" || echo "✗")"
    echo ""
done
```

---

## Best Practices Summary

1. ✅ **Automate**: Use scripts for client provisioning
2. ✅ **Document**: Keep client registry with contact info
3. ✅ **Audit**: Review access logs monthly
4. ✅ **Rotate**: Update Secret IDs every 90 days
5. ✅ **Backup**: Regular backups of all client secrets
6. ✅ **Monitor**: Track usage metrics per client
7. ✅ **Secure**: Never commit credentials to version control
8. ✅ **Test**: Verify client access after provisioning

---

## Next Steps

1. Provision your first client
2. Integrate client application with Vault
3. Setup monitoring for client access
4. Document client-specific configurations
5. Train client administrators on Vault usage
