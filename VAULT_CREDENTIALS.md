# Vault AppRole Credentials

## ⚠️ IMPORTANT - Save These Credentials Securely!

### AppRole Credentials
```
Role ID:     6a916804-395f-6547-9df1-08acf9763928
Secret ID:   7848640d-ffa9-02c0-b9fb-08014d6667c1
```

### Root Token (Admin Only)
```
Root Token:  myroot
```

### Vault Access
```
Vault UI:    http://localhost:8300/ui
API:         http://localhost:8300
```

## Spring Boot Configuration

Add these environment variables to your application:

```bash
VAULT_ROLE_ID=6a916804-395f-6547-9df1-08acf9763928
VAULT_SECRET_ID=7848640d-ffa9-02c0-b9fb-08014d6667c1
```

## Test AppRole Login

```bash
# Test login with AppRole credentials
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 vault-prod sh -c "vault write auth/approle/login role_id=6a916804-395f-6547-9df1-08acf9763928 secret_id=7848640d-ffa9-02c0-b9fb-08014d6667c1"
```

## Stored Secrets

### Database Credentials
Path: `secret/payment-service/database`
- username: payment_user
- password: secure_password_123
- host: localhost
- port: 5432
- database: payment_db

## Read Secrets

```bash
# Read database credentials
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod sh -c "vault kv get secret/payment-service/database"

# Read as JSON
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod sh -c "vault kv get -format=json secret/payment-service/database"
```

## Security Notes

1. **Never commit these credentials to Git**
2. **Root token** (`myroot`) should only be used for admin tasks
3. **Secret ID** should be rotated periodically
4. **Role ID** can be stored in application config (less sensitive)
5. **Secret ID** should be provided via environment variable or secure secret management

## Rotate Secret ID

When you need to rotate the Secret ID:

```bash
# Generate new Secret ID
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod sh -c "vault write -f auth/approle/role/payment-service/secret-id"

# Update VAULT_SECRET_ID environment variable in your application
```

## Next Steps

1. ✅ AppRole enabled
2. ✅ Policy created
3. ✅ AppRole configured
4. ✅ Credentials generated
5. ✅ Secrets stored
6. ⏳ Configure Spring Boot application
7. ⏳ Test integration

See `DEV_MODE_SETUP.md` for Spring Boot integration details.
