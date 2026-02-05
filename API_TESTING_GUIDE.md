# Vault API Testing Guide

## 🚀 Quick Start

### 1. Set Environment Variables (Optional)

The application has default values, but you can override them:

```bash
# Windows CMD
set VAULT_ROLE_ID=6a916804-395f-6547-9df1-08acf9763928
set VAULT_SECRET_ID=7848640d-ffa9-02c0-b9fb-08014d6667c1

# Windows PowerShell
$env:VAULT_ROLE_ID="6a916804-395f-6547-9df1-08acf9763928"
$env:VAULT_SECRET_ID="7848640d-ffa9-02c0-b9fb-08014d6667c1"

# Linux/Mac
export VAULT_ROLE_ID=6a916804-395f-6547-9df1-08acf9763928
export VAULT_SECRET_ID=7848640d-ffa9-02c0-b9fb-08014d6667c1
```

### 2. Start the Application

```bash
# Using Maven
mvn spring-boot:run

# Or using Maven Wrapper
./mvnw spring-boot:run

# Or run the JAR
mvn clean package
java -jar target/voult-demo-0.0.1-SNAPSHOT.jar
```

### 3. Verify Vault is Running

```bash
docker ps
# Should show vault-prod container running
```

## 📡 API Endpoints

### 1. Health Check
Check if Vault connection is working.

**Request:**
```bash
GET http://localhost:8080/api/vault/health
```

**cURL:**
```bash
curl http://localhost:8080/api/vault/health
```

**Expected Response:**
```json
{
  "status": "UP",
  "vault": "Connected",
  "message": "Successfully connected to Vault",
  "secretsAvailable": true
}
```

---

### 2. Get Database Configuration (Masked)
Retrieve database configuration with masked password.

**Request:**
```bash
GET http://localhost:8080/api/vault/database-config
```

**cURL:**
```bash
curl http://localhost:8080/api/vault/database-config
```

**Expected Response:**
```json
{
  "status": "success",
  "source": "HashiCorp Vault",
  "config": {
    "username": "payment_user",
    "password": "***MASKED***",
    "host": "localhost",
    "port": 5432,
    "database": "payment_db"
  }
}
```

---

### 3. Get Raw Secrets (Testing Only!)
⚠️ **WARNING**: This endpoint exposes actual secrets! Only for testing!

**Request:**
```bash
GET http://localhost:8080/api/vault/secrets/database
```

**cURL:**
```bash
curl http://localhost:8080/api/vault/secrets/database
```

**Expected Response:**
```json
{
  "status": "success",
  "path": "secret/payment-service/database",
  "data": {
    "username": "payment_user",
    "password": "secure_password_123",
    "host": "localhost",
    "port": 5432,
    "database": "payment_db"
  },
  "metadata": {
    "version": {
      "created_time": "2026-02-05T06:42:00.123456Z",
      "version": 1
    }
  }
}
```

---

### 4. Test @Value Annotation
Test Spring's @Value annotation with Vault.

**Request:**
```bash
GET http://localhost:8080/api/vault/test-value
```

**cURL:**
```bash
curl http://localhost:8080/api/vault/test-value
```

**Expected Response:**
```json
{
  "status": "success",
  "message": "Values loaded from Vault using @Value annotation",
  "values": {
    "username": "payment_user",
    "host": "localhost",
    "password": "***MASKED***"
  }
}
```

---

### 5. Get Vault Connection Info
Get information about Vault configuration.

**Request:**
```bash
GET http://localhost:8080/api/vault/info
```

**cURL:**
```bash
curl http://localhost:8080/api/vault/info
```

**Expected Response:**
```json
{
  "vaultConfigured": true,
  "databaseConfigLoaded": true,
  "authMethod": "AppRole",
  "vaultUri": "http://localhost:8300",
  "secretsPath": "secret/payment-service"
}
```

## 🧪 Testing with Postman

### Import Collection

Create a new Postman collection with these requests:

1. **Health Check**
   - Method: GET
   - URL: `http://localhost:8080/api/vault/health`

2. **Database Config**
   - Method: GET
   - URL: `http://localhost:8080/api/vault/database-config`

3. **Raw Secrets**
   - Method: GET
   - URL: `http://localhost:8080/api/vault/secrets/database`

4. **Test Value**
   - Method: GET
   - URL: `http://localhost:8080/api/vault/test-value`

5. **Vault Info**
   - Method: GET
   - URL: `http://localhost:8080/api/vault/info`

## 🔧 Troubleshooting

### Application Won't Start

**Error:** `VaultException: Cannot login using AppRole`

**Solution:**
1. Verify Vault is running:
   ```bash
   docker ps | grep vault-prod
   ```

2. Check AppRole credentials in `application.yml`

3. Verify secrets exist in Vault:
   ```bash
   docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod sh -c "vault kv get secret/payment-service/database"
   ```

---

**Error:** `Connection refused to localhost:8300`

**Solution:**
1. Check if Vault container is running on port 8300:
   ```bash
   docker ps
   ```

2. Verify port mapping in `docker-compose.dev.yml`

---

### Secrets Not Loading

**Error:** Properties show `NOT_LOADED`

**Solution:**
1. Check application logs for Vault connection errors

2. Verify the secret path matches:
   - Application expects: `secret/payment-service/database`
   - Check in Vault:
     ```bash
     docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod sh -c "vault kv list secret/payment-service"
     ```

3. Ensure AppRole has correct permissions:
   ```bash
   docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod sh -c "vault policy read payment-service"
   ```

---

### 403 Forbidden Error

**Error:** `permission denied`

**Solution:**
The AppRole doesn't have permission to read the secret path.

1. Verify policy:
   ```bash
   docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod sh -c "vault policy read payment-service"
   ```

2. Should show:
   ```hcl
   path "secret/data/payment-service/*" {
     capabilities = ["read", "list"]
   }
   ```

## 📝 Adding More Secrets

### Store API Keys

```bash
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod sh -c "vault kv put secret/payment-service/api-keys stripe_key=sk_test_xxxxx paypal_key=xxxxx"
```

### Access in Code

```java
@Value("${api-keys.stripe_key}")
private String stripeKey;

@Value("${api-keys.paypal_key}")
private String paypalKey;
```

## 🔐 Security Best Practices

1. **Never expose the `/secrets/database` endpoint in production**
   - Remove or secure it with authentication

2. **Use environment variables for credentials**
   - Don't hardcode Role ID and Secret ID in `application.yml`

3. **Rotate Secret ID regularly**
   ```bash
   docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod sh -c "vault write -f auth/approle/role/payment-service/secret-id"
   ```

4. **Enable audit logging**
   ```bash
   docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=myroot vault-prod sh -c "vault audit enable file file_path=/vault/logs/audit.log"
   ```

5. **Monitor audit logs**
   ```bash
   docker exec vault-prod tail -f /vault/logs/audit.log
   ```

## 📊 Application Logs

Enable debug logging to see Vault interactions:

```yaml
logging:
  level:
    org.springframework.cloud.vault: DEBUG
    org.springframework.vault: DEBUG
```

Look for these log messages:
- `✓ Vault login successful`
- `✓ Lease renewed`
- `✓ Secrets loaded from vault://secret/payment-service`

## 🎯 Next Steps

1. ✅ Test all API endpoints
2. ✅ Verify secrets are loaded correctly
3. ✅ Check application logs for any errors
4. 🔄 Integrate secrets into your actual application logic
5. 🔄 Add more secrets as needed
6. 🔄 Implement proper error handling
7. 🔄 Add authentication to your API endpoints

## 📚 Additional Resources

- [Spring Cloud Vault Documentation](https://docs.spring.io/spring-cloud-vault/docs/current/reference/html/)
- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [AppRole Authentication](https://www.vaultproject.io/docs/auth/approle)
