# HashiCorp Vault Integration with Spring Boot

This project demonstrates how to integrate HashiCorp Vault with Spring Boot 3.x/4.x on Windows using Docker Desktop.

## Prerequisites

- **Java 21** or higher
- **Maven** 3.6+
- **Docker Desktop** for Windows (running)
- **Spring Boot 4.0.2**

## Project Structure

```
voult-demo/
├── docker-compose.yml                          # Vault container configuration
├── pom.xml                                     # Maven dependencies
├── src/main/
│   ├── resources/
│   │   └── application.yml                     # Spring Boot + Vault config
│   └── java/com/rana/voult_demo/
│       ├── config/
│       │   └── PaymentProperties.java          # @ConfigurationProperties
│       └── controller/
│           └── PaymentController.java          # REST endpoints
```

---

## 🚀 Quick Start Guide

### Step 1: Start Vault Container

Open PowerShell or Command Prompt in the project directory:

```bash
docker-compose up -d
```

Verify Vault is running:

```bash
docker ps
```

You should see the `vault-dev` container running on port `8200`.

### Step 2: Configure Vault Secrets

#### Option A: Using Docker Exec (Recommended for Windows)

```bash
# Access the Vault container
docker exec -it vault-dev sh

# Inside the container, set the Vault address and token
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='dev-root-token'

# Enable KV v2 secrets engine (if not already enabled)
vault secrets enable -path=secret kv-v2

# Store test secrets at secret/payment-service
vault kv put secret/payment-service \
  payment.apiKey="sk_test_1234567890abcdef" \
  payment.merchantId="merchant_xyz123" \
  payment.webhookSecret="whsec_abcdefghijklmnop"

# Verify the secrets were stored
vault kv get secret/payment-service

# Exit the container
exit
```

#### Option B: Using Vault CLI on Windows Host

If you have Vault CLI installed on Windows:

```powershell
# Set environment variables
$env:VAULT_ADDR="http://localhost:8200"
$env:VAULT_TOKEN="dev-root-token"

# Enable KV v2 secrets engine
vault secrets enable -path=secret kv-v2

# Store secrets
vault kv put secret/payment-service payment.apiKey="sk_test_1234567890abcdef" payment.merchantId="merchant_xyz123" payment.webhookSecret="whsec_abcdefghijklmnop"

# Verify
vault kv get secret/payment-service
```

### Step 3: Run Spring Boot Application

```bash
# Build the project
mvn clean install

# Run the application
mvn spring-boot:run
```

The application will start on `http://localhost:8080`.

### Step 4: Test the Integration

Open your browser or use `curl` to test the endpoints:

#### Get All Payment Configuration
```bash
curl http://localhost:8080/api/payment/config
```

**Expected Response:**
```json
{
  "apiKey": "sk_test_1234567890abcdef",
  "merchantId": "merchant_xyz123",
  "webhookSecret": "whsec_abcdefghijklmnop"
}
```

#### Get API Key (using @Value)
```bash
curl http://localhost:8080/api/payment/api-key
```

**Expected Response:**
```json
{
  "apiKey": "sk_test_1234567890abcdef",
  "source": "Retrieved using @Value annotation"
}
```

#### Health Check
```bash
curl http://localhost:8080/api/payment/health
```

**Expected Response:**
```json
{
  "status": "UP",
  "message": "Payment service is running with Vault integration"
}
```

---

## 📋 Configuration Details

### Docker Compose Configuration

The `docker-compose.yml` runs Vault in **development mode**:

- **Port**: `8200` (accessible from Windows host)
- **Root Token**: `dev-root-token`
- **Mode**: Development (data is NOT persisted)
- **Network**: Bridge network for container isolation

> ⚠️ **Warning**: Dev mode is for testing only. Do NOT use in production!

### Spring Boot Configuration

The `application.yml` uses `spring.config.import` (Spring Boot 2.4+):

```yaml
spring:
  config:
    import: vault://
  cloud:
    vault:
      uri: http://localhost:8200
      authentication: TOKEN
      token: dev-root-token
      kv:
        enabled: true
        backend: secret
        default-context: payment-service
```

**Key Points:**
- `spring.config.import: vault://` - Enables Vault integration
- `uri` - Vault server address (accessible from Windows host)
- `authentication: TOKEN` - Uses token-based authentication
- `default-context: payment-service` - Maps to Vault path `secret/payment-service`

### Maven Dependencies

```xml
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-vault-config</artifactId>
</dependency>
```

Spring Cloud version: `2024.0.0` (compatible with Spring Boot 4.x)

---

## 🔧 Vault CLI Commands Reference

### Enable KV v2 Engine
```bash
vault secrets enable -path=secret kv-v2
```

### Store Secrets
```bash
vault kv put secret/payment-service \
  payment.apiKey="your-api-key" \
  payment.merchantId="your-merchant-id" \
  payment.webhookSecret="your-webhook-secret"
```

### Read Secrets
```bash
vault kv get secret/payment-service
```

### Read Specific Field
```bash
vault kv get -field=payment.apiKey secret/payment-service
```

### Update Secrets (creates new version)
```bash
vault kv put secret/payment-service \
  payment.apiKey="new-api-key" \
  payment.merchantId="merchant_xyz123" \
  payment.webhookSecret="whsec_abcdefghijklmnop"
```

### Delete Secrets
```bash
vault kv delete secret/payment-service
```

### List All Secrets
```bash
vault kv list secret/
```

---

## 💡 Code Examples

### Using @ConfigurationProperties

```java
@Component
@ConfigurationProperties(prefix = "payment")
public class PaymentProperties {
    private String apiKey;
    private String merchantId;
    private String webhookSecret;
    
    // Getters and setters
}
```

### Using @Value

```java
@RestController
public class PaymentController {
    
    @Value("${payment.apiKey}")
    private String apiKey;
    
    @GetMapping("/api-key")
    public String getApiKey() {
        return apiKey;
    }
}
```

---

## 🛠️ Troubleshooting

### Issue: Application fails to start with "Connection refused"

**Solution**: Ensure Vault container is running:
```bash
docker ps
docker-compose up -d
```

### Issue: "Authentication failed" error

**Solution**: Verify the token in `application.yml` matches the Vault root token:
```yaml
spring.cloud.vault.token: dev-root-token
```

### Issue: Secrets not found

**Solution**: Verify secrets are stored at the correct path:
```bash
docker exec -it vault-dev sh
vault kv get secret/payment-service
```

### Issue: Port 8200 already in use

**Solution**: Stop any existing Vault instances or change the port in `docker-compose.yml`:
```yaml
ports:
  - "8201:8200"  # Change host port to 8201
```

Then update `application.yml`:
```yaml
spring.cloud.vault.uri: http://localhost:8201
```

---

## 🔒 Security Best Practices

1. **Never use dev mode in production** - Dev mode stores data in memory and uses a static root token
2. **Use AppRole or Kubernetes auth** in production instead of static tokens
3. **Enable TLS/SSL** for Vault communication in production
4. **Rotate secrets regularly** using Vault's dynamic secrets feature
5. **Use environment variables** for sensitive configuration instead of hardcoding in `application.yml`

---

## 📚 Additional Resources

- [Spring Cloud Vault Documentation](https://docs.spring.io/spring-cloud-vault/docs/current/reference/html/)
- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [Vault KV Secrets Engine](https://www.vaultproject.io/docs/secrets/kv)
- [Spring Boot Configuration](https://docs.spring.io/spring-boot/docs/current/reference/html/features.html#features.external-config)

---

## 📝 Notes

- **Dev Mode**: Data is stored in memory and lost when container stops
- **Windows Compatibility**: Uses `localhost:8200` for host-to-container communication
- **Spring Boot 4.x**: Uses Spring Cloud `2024.0.0` for compatibility
- **KV v2**: Supports versioning and secret rollback

---

## 🎯 Next Steps

1. Explore dynamic secrets (database credentials, AWS credentials)
2. Implement AppRole authentication for production
3. Set up Vault policies for fine-grained access control
4. Enable audit logging
5. Configure Vault high availability (HA) setup

---

**Happy Coding! 🚀**
