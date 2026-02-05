# Vault Setup Guide - Dev Mode with Production Features

## Overview

This setup uses Vault in **dev mode** with persistent storage and production-like features. While dev mode auto-unseals (convenient for development), you still get:
- ✅ Persistent storage
- ✅ AppRole authentication
- ✅ Policy-based access control
- ✅ Audit logging
- ✅ Automatic restart

> **Note**: For true production with manual unsealing, you'd need to resolve the HCL configuration issue. This dev mode setup is suitable for development and testing environments.

## Quick Start

```bash
# Start Vault
docker-compose -f docker-compose.dev.yml up -d

# Check status
docker ps
docker logs vault-prod

# Access UI
# Open: http://localhost:8300/ui
# Token: myroot
```

## Setup AppRole Authentication

### 1. Enable AppRole Auth Method

```bash
# Enable AppRole (note: VAULT_ADDR must be HTTP, not HTTPS)
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod vault auth enable approle
```

### 2. Create Policy for Your Application

```bash
# Create policy file
docker exec vault-prod sh -c "cat > /tmp/payment-service-policy.hcl << 'EOF'
path \"secret/data/payment-service/*\" {
  capabilities = [\"read\", \"list\"]
}

path \"secret/metadata/payment-service/*\" {
  capabilities = [\"list\"]
}
EOF"

# Write the policy
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod vault policy write payment-service /tmp/payment-service-policy.hcl
```

### 3. Create AppRole

```bash
# Create the AppRole
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod vault write auth/approle/role/payment-service \
    token_ttl=1h \
    token_max_ttl=4h \
    policies=payment-service

# Get Role ID (this is public, can be in your application config)
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod vault read auth/approle/role/payment-service/role-id

# Generate Secret ID (this is private, should be securely provided to the application)
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod vault write -f auth/approle/role/payment-service/secret-id
```

### 4. Store Your Secrets

```bash
# Enable KV v2 secrets engine (if not already enabled)
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod vault secrets enable -path=secret kv-v2

# Store database credentials
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod vault kv put secret/payment-service/database \
    username=payment_user \
    password=secure_password_123 \
    host=localhost \
    port=5432 \
    database=payment_db

# Store API keys
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod vault kv put secret/payment-service/api-keys \
    stripe_key=sk_test_xxxxxxxxxxxxx \
    paypal_key=xxxxxxxxxxxxx
```

## Enable Audit Logging

```bash
# Enable file-based audit logging
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod vault audit enable file file_path=/vault/logs/audit.log

# View audit logs
docker exec vault-prod tail -f /vault/logs/audit.log
```

## Spring Boot Integration

### 1. Add Dependencies (pom.xml)

```xml
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-vault-config</artifactId>
</dependency>
```

### 2. Configure Application (application.yml)

```yaml
spring:
  cloud:
    vault:
      uri: http://localhost:8300
      authentication: APPROLE
      app-role:
        role-id: ${VAULT_ROLE_ID}
        secret-id: ${VAULT_SECRET_ID}
        role: payment-service
        app-role-path: approle
      kv:
        enabled: true
        backend: secret
        application-name: payment-service
```

### 3. Environment Variables

Set these in your application environment:

```bash
VAULT_ROLE_ID=<role-id-from-step-3>
VAULT_SECRET_ID=<secret-id-from-step-3>
```

### 4. Access Secrets in Code

```java
@Configuration
@ConfigurationProperties(prefix = "database")
public class DatabaseConfig {
    private String username;
    private String password;
    private String host;
    private int port;
    private String database;
    
    // Getters and setters
}
```

Spring will automatically inject values from `secret/payment-service/database`.

## Security Features

### 1. Persistent Storage
- Data stored in `./vault/data` directory
- Survives container restarts
- In dev mode, data is stored in-memory but can be configured for persistence

### 2. Auto-Unsealing (Dev Mode)
- Vault automatically unseals on startup
- Convenient for development
- For production, use server mode with manual unsealing

### 3. AppRole Authentication
- No static root token in application
- Role ID (public) + Secret ID (private)
- Tokens auto-expire (1 hour TTL, 4 hour max)

### 4. Policy-Based Access
- Least privilege principle
- Application can only read `secret/payment-service/*`
- Cannot access other secrets or perform write operations

### 5. Audit Logging
- All Vault operations logged to `/vault/logs/audit.log`
- Includes authentication attempts, secret access, policy changes
- Useful for compliance and security monitoring

## Useful Commands

### Check Vault Status
```bash
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod vault status
```

### List All Secrets
```bash
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod vault kv list secret/payment-service
```

### Read a Secret
```bash
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod vault kv get secret/payment-service/database
```

### Rotate Secret ID
```bash
# Generate new Secret ID
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod vault write -f auth/approle/role/payment-service/secret-id

# Update your application with the new Secret ID
```

### View Audit Logs
```bash
# Real-time monitoring
docker exec vault-prod tail -f /vault/logs/audit.log

# View last 50 lines
docker exec vault-prod tail -n 50 /vault/logs/audit.log
```

### Backup Vault Data
```bash
# Stop Vault
docker-compose -f docker-compose.dev.yml down

# Backup data directory
tar -czf vault-backup-$(date +%Y%m%d).tar.gz ./vault/data

# Restart Vault
docker-compose -f docker-compose.dev.yml up -d
```

## Troubleshooting

### Container Won't Start
```bash
# Check logs
docker logs vault-prod

# Remove and restart
docker-compose -f docker-compose.dev.yml down
docker-compose -f docker-compose.dev.yml up -d
```

### Can't Access Secrets
```bash
# Verify token
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod vault token lookup

# Check policies
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod vault policy read payment-service

# Test AppRole login
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 vault-prod vault write auth/approle/login \
    role_id=<your-role-id> \
    secret_id=<your-secret-id>
```

### Reset Everything
```bash
# Stop and remove container
docker-compose -f docker-compose.dev.yml down

# Remove data (WARNING: This deletes all secrets!)
rm -rf ./vault/data/*
rm -rf ./vault/logs/*

# Start fresh
docker-compose -f docker-compose.dev.yml up -d
```

## Migration to Production Mode

When you're ready to move to true production mode with manual unsealing:

1. Resolve the HCL configuration issue (port binding problem)
2. Use `docker-compose.prod.yml` with proper `vault.hcl`
3. Initialize Vault and save unseal keys securely
4. Distribute unseal keys to multiple administrators
5. Update application configuration (port might change)

## Access Information

- **Vault UI**: http://localhost:8300/ui
- **Root Token**: `myroot` (for admin operations only)
- **API Endpoint**: http://localhost:8300
- **Health Check**: http://localhost:8300/v1/sys/health

## Notes

- Dev mode is **NOT recommended for production** due to auto-unsealing
- Root token `myroot` should be changed in production
- This setup provides a good balance for development and testing
- All production features (AppRole, policies, audit) work the same way
