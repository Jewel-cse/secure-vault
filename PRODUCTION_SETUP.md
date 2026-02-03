# 🔐 Production Vault Setup Guide

This guide walks you through setting up HashiCorp Vault in **production mode** with persistent storage, AppRole authentication, and security best practices.

---

## 📋 Prerequisites

- Docker Desktop running
- Java 21+
- Maven 3.6+
- Basic understanding of Vault concepts

---

## 🚀 Quick Start (Production)

### Step 1: Start Vault in Production Mode

```bash
# Use production docker-compose
docker-compose -f docker-compose.prod.yml up -d

# Verify Vault is running
docker ps
```

### Step 2: Initialize Vault (ONE TIME ONLY!)

**For Linux/Mac:**
```bash
cd vault/scripts
chmod +x init-vault.sh
./init-vault.sh
```

**For Windows (PowerShell):**
```powershell
# Initialize Vault
docker exec vault-prod vault operator init -key-shares=5 -key-threshold=3 > vault-keys.txt

# Unseal Vault (use keys from vault-keys.txt)
docker exec vault-prod vault operator unseal <KEY1>
docker exec vault-prod vault operator unseal <KEY2>
docker exec vault-prod vault operator unseal <KEY3>
```

**⚠️ CRITICAL:** 
- `vault-keys.txt` contains your **unseal keys** and **root token**
- Store this file in a **secure location** (password manager, encrypted storage)
- **NEVER commit to git** (already in .gitignore)
- Distribute unseal keys to different trusted individuals

### Step 3: Complete Setup

After unsealing, run the setup commands:

```bash
# Set root token from vault-keys.txt
export VAULT_TOKEN="<root-token-from-vault-keys.txt>"

# Enable KV v2 secrets engine
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-prod vault secrets enable -path=secret kv-v2

# Enable AppRole authentication
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-prod vault auth enable approle

# Create policy for payment-service
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-prod vault policy write payment-service /vault/policies/payment-service-policy.hcl

# Create AppRole
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-prod vault write auth/approle/role/payment-service \
    token_policies="payment-service" \
    token_ttl=1h \
    token_max_ttl=4h

# Get Role ID
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-prod vault read -field=role_id auth/approle/role/payment-service/role-id

# Generate Secret ID
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-prod vault write -field=secret_id -f auth/approle/role/payment-service/secret-id
```

**Save the Role ID and Secret ID** - you'll need these for your application!

### Step 4: Store Secrets

```bash
# Store production secrets
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-prod vault kv put secret/payment-service \
  payment.apiKey="sk_prod_your_real_key" \
  payment.merchantId="merchant_prod_xyz" \
  payment.webhookSecret="whsec_prod_secret"

# Verify secrets
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-prod vault kv get secret/payment-service
```

### Step 5: Configure Spring Boot

Create environment variables:

**Windows (PowerShell):**
```powershell
$env:VAULT_ROLE_ID="<your-role-id>"
$env:VAULT_SECRET_ID="<your-secret-id>"
```

**Linux/Mac:**
```bash
export VAULT_ROLE_ID="<your-role-id>"
export VAULT_SECRET_ID="<your-secret-id>"
```

**Or create a `.env` file** (already in .gitignore):
```env
VAULT_ROLE_ID=your-role-id-here
VAULT_SECRET_ID=your-secret-id-here
```

### Step 6: Run Application

```bash
# Run with production profile
mvn spring-boot:run -Dspring.profiles.active=prod

# Or with environment variables
VAULT_ROLE_ID=xxx VAULT_SECRET_ID=yyy mvn spring-boot:run -Dspring.profiles.active=prod
```

---

## 🏗️ Architecture

### Production Setup

```
┌─────────────────────────────────────────────────────────┐
│                    Docker Host                          │
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │  Vault Container (vault-prod)                  │    │
│  │                                                 │    │
│  │  ┌──────────────────────────────────────┐     │    │
│  │  │  Vault Server (Production Mode)      │     │    │
│  │  │  - File Storage Backend              │     │    │
│  │  │  - AppRole Authentication            │     │    │
│  │  │  - Policy-based Access Control       │     │    │
│  │  └──────────────────────────────────────┘     │    │
│  │                                                 │    │
│  │  Volumes:                                      │    │
│  │  - ./vault/data   → /vault/file (persistent)  │    │
│  │  - ./vault/config → /vault/config             │    │
│  │  - ./vault/logs   → /vault/logs               │    │
│  └────────────────────────────────────────────────┘    │
│                         ↑                               │
│                         │ HTTP (localhost:8200)         │
│                         │                               │
│  ┌────────────────────────────────────────────────┐    │
│  │  Spring Boot Application                       │    │
│  │  - AppRole Auth (Role ID + Secret ID)         │    │
│  │  - Reads from secret/payment-service          │    │
│  └────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

---

## 🔒 Security Features

### 1. **Persistent Storage**
- Data stored in `./vault/data` directory
- Survives container restarts
- Encrypted at rest

### 2. **Unsealing**
- Vault starts **sealed** (encrypted)
- Requires 3 of 5 unseal keys to unlock
- Keys distributed to different administrators

### 3. **AppRole Authentication**
- **No static root token** in application
- Role ID (public) + Secret ID (private)
- Tokens auto-expire (1 hour TTL)

### 4. **Policy-Based Access**
- Least privilege principle
- Application can only read `secret/payment-service/*`
- Cannot access other secrets

### 5. **Audit Logging** (Optional)
```bash
# Enable audit logging
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-prod vault audit enable file file_path=/vault/logs/audit.log
```

---

## 📂 File Structure

```
voult-demo/
├── docker-compose.yml              # Dev mode (in-memory)
├── docker-compose.prod.yml         # Production mode (persistent)
├── vault/
│   ├── config/
│   │   └── vault.hcl              # Vault server configuration
│   ├── policies/
│   │   └── payment-service-policy.hcl  # Access policy
│   ├── scripts/
│   │   ├── init-vault.sh          # Linux/Mac initialization
│   │   └── init-vault.bat         # Windows initialization
│   ├── data/                      # Persistent storage (gitignored)
│   ├── logs/                      # Vault logs (gitignored)
│   └── certs/                     # TLS certificates (gitignored)
├── src/main/resources/
│   ├── application.yml            # Dev configuration (TOKEN auth)
│   └── application-prod.yml       # Prod configuration (APPROLE auth)
└── .gitignore                     # Excludes sensitive files
```

---

## 🔄 Vault Unsealing Process

Vault starts **sealed** after every restart. You must unseal it:

### Automatic Unsealing (Recommended for Production)

Use **auto-unseal** with cloud KMS:
- AWS KMS
- Azure Key Vault
- GCP Cloud KMS

### Manual Unsealing

```bash
# Check status
docker exec vault-prod vault status

# Unseal (requires 3 keys)
docker exec vault-prod vault operator unseal <KEY1>
docker exec vault-prod vault operator unseal <KEY2>
docker exec vault-prod vault operator unseal <KEY3>

# Verify unsealed
docker exec vault-prod vault status
```

---

## 🔑 AppRole Authentication Flow

```
1. Application starts
   ↓
2. Reads VAULT_ROLE_ID and VAULT_SECRET_ID from environment
   ↓
3. Sends Role ID + Secret ID to Vault
   ↓
4. Vault validates credentials
   ↓
5. Vault returns short-lived token (1 hour TTL)
   ↓
6. Application uses token to read secrets
   ↓
7. Token auto-renews before expiration
```

---

## 🛠️ Troubleshooting

### Issue: Vault is sealed

**Solution:**
```bash
docker exec vault-prod vault status
# If sealed=true, unseal with 3 keys
docker exec vault-prod vault operator unseal <KEY>
```

### Issue: AppRole authentication failed

**Solution:**
```bash
# Verify Role ID and Secret ID are correct
echo $VAULT_ROLE_ID
echo $VAULT_SECRET_ID

# Test authentication manually
docker exec vault-prod vault write auth/approle/login \
  role_id="$VAULT_ROLE_ID" \
  secret_id="$VAULT_SECRET_ID"
```

### Issue: Permission denied

**Solution:**
```bash
# Verify policy is attached to role
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-prod vault read auth/approle/role/payment-service

# Check policy contents
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-prod vault policy read payment-service
```

---

## 🔄 Secret Rotation

### Rotate Secret ID (Recommended: Every 90 days)

```bash
# Generate new Secret ID
NEW_SECRET_ID=$(docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-prod vault write -field=secret_id -f auth/approle/role/payment-service/secret-id)

# Update application environment variable
export VAULT_SECRET_ID="$NEW_SECRET_ID"

# Restart application
```

### Rotate Application Secrets

```bash
# Update secrets (creates new version)
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-prod vault kv put secret/payment-service \
  payment.apiKey="new-rotated-key"

# Restart application to pick up new secrets
```

---

## 📊 Comparison: Dev vs Production

| Feature | Dev Mode | Production Mode |
|---------|----------|-----------------|
| **Storage** | In-memory | Persistent (file) |
| **Unsealing** | Auto | Manual (3 of 5 keys) |
| **Authentication** | Root token | AppRole |
| **Data Persistence** | ❌ Lost on restart | ✅ Survives restarts |
| **Security** | ⚠️ Low | ✅ High |
| **TLS** | ❌ HTTP only | ✅ HTTPS (optional) |
| **Policies** | ❌ None | ✅ Least privilege |
| **Use Case** | Local dev/testing | Staging/Production |

---

## 🎯 Next Steps

1. **Enable TLS/SSL** for encrypted communication
2. **Set up auto-unseal** with cloud KMS
3. **Configure high availability** with Consul or Raft
4. **Implement secret rotation** schedule
5. **Enable audit logging** for compliance
6. **Set up monitoring** and alerting

---

## 📚 Additional Resources

- [Vault Production Hardening](https://learn.hashicorp.com/tutorials/vault/production-hardening)
- [AppRole Authentication](https://www.vaultproject.io/docs/auth/approle)
- [Vault Policies](https://www.vaultproject.io/docs/concepts/policies)
- [Spring Cloud Vault](https://docs.spring.io/spring-cloud-vault/docs/current/reference/html/)

---

**🔐 Remember: Security is a process, not a product. Regularly review and update your Vault configuration!**
