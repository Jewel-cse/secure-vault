# Troubleshooting: Secrets Not Loading

## Problem
- `/api/vault/health` shows `secretsAvailable: false`
- `/api/vault/info` shows Vault is configured
- Vault container is running

## Quick Diagnosis

### 1. Check Application Logs

Look for these messages in your Spring Boot logs:

**✅ Good Signs:**
```
Vault login successful
Lease renewed
Secrets loaded from vault://secret/payment-service
```

**❌ Bad Signs:**
```
VaultException: Cannot login using AppRole
403 permission denied
Connection refused
```

### 2. Verify Secret Exists in Vault

```bash
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod sh -c "vault kv get secret/payment-service/database"
```

**Expected output:**
```
====== Data ======
Key         Value
---         -----
database    payment_db
host        localhost
password    secure_password_123
port        5432
username    payment_user
```

### 3. Test AppRole Login

```bash
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 vault-prod sh -c "vault write auth/approle/login role_id=6a916804-395f-6547-9df1-08acf9763928 secret_id=7848640d-ffa9-02c0-b9fb-08014d6667c1"
```

**Expected:** Should return a `client_token`

### 4. Check AppRole Permissions

```bash
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod sh -c "vault policy read payment-service"
```

**Expected:**
```hcl
path "secret/data/payment-service/*" {
  capabilities = ["read", "list"]
}
```

## Common Issues & Solutions

### Issue 1: Wrong Secret Path

**Problem:** Spring Cloud Vault looks for secrets at a specific path structure.

**Solution:** Spring Cloud Vault with `default-context: payment-service` expects secrets at:
- `secret/data/payment-service` (for KV v2)

But we stored them at:
- `secret/payment-service/database`

**Fix Option 1 - Update application.yml:**
```yaml
spring:
  cloud:
    vault:
      kv:
        enabled: true
        backend: secret
        default-context: payment-service
        profiles: database  # Add this
```

**Fix Option 2 - Restructure secrets in Vault:**
```bash
# Store at the root of payment-service context
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod sh -c "vault kv put secret/payment-service username=payment_user password=secure_password_123 host=localhost port=5432 database=payment_db"
```

### Issue 2: AppRole Authentication Failing

**Problem:** Role ID or Secret ID is incorrect.

**Solution:**
1. Verify environment variables are set:
   ```bash
   echo %VAULT_ROLE_ID%
   echo %VAULT_SECRET_ID%
   ```

2. Restart the application after setting environment variables

3. Check application logs for authentication errors

### Issue 3: Vault Not Accessible

**Problem:** Application can't reach Vault at `localhost:8300`.

**Solution:**
1. Verify Vault is running:
   ```bash
   docker ps | grep vault-prod
   ```

2. Test connectivity:
   ```bash
   curl http://localhost:8300/v1/sys/health
   ```

## Recommended Fix

The most likely issue is the secret path structure. Try this:

### Step 1: Store secrets at the correct path

```bash
# Store secrets at the root of payment-service context
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod sh -c "vault kv put secret/payment-service username=payment_user password=secure_password_123 host=localhost port=5432 database=payment_db"
```

### Step 2: Restart your Spring Boot application

```bash
# Stop the app (Ctrl+C)
# Then restart
mvn spring-boot:run
```

### Step 3: Test again

```bash
curl http://localhost:8080/api/vault/health
curl http://localhost:8080/api/vault/database-config
```

## Alternative: Use Generic Backend

If the above doesn't work, try using the generic backend:

**Update application.yml:**
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
      generic:
        enabled: true
        application-name: payment-service
      kv:
        enabled: false  # Disable KV, use generic instead
```

## Check Current Status

Run these commands to see what's happening:

```bash
# 1. Check if secret exists
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod sh -c "vault kv list secret/"

# 2. Check payment-service path
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod sh -c "vault kv list secret/payment-service"

# 3. Test AppRole login
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 vault-prod sh -c "vault write auth/approle/login role_id=6a916804-395f-6547-9df1-08acf9763928 secret_id=7848640d-ffa9-02c0-b9fb-08014d6667c1"
```

## Need More Help?

Share your application logs (especially lines containing "Vault" or "vault") and the output of the diagnostic commands above.
