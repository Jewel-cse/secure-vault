# 🚀 Quick Reference - Vault Integration

## Start Vault
```bash
docker-compose up -d
```

## Setup Vault Secrets
```bash
# Access container
docker exec -it vault-dev sh

# Inside container
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='dev-root-token'

# Enable KV v2
vault secrets enable -path=secret kv-v2

# Store secrets
vault kv put secret/payment-service \
  payment.apiKey="sk_test_1234567890abcdef" \
  payment.merchantId="merchant_xyz123" \
  payment.webhookSecret="whsec_abcdefghijklmnop"

# Verify
vault kv get secret/payment-service

# Exit
exit
```

## Run Spring Boot
```bash
mvn clean install
mvn spring-boot:run
```

## Test Endpoints
```bash
# Get all config
curl http://localhost:8080/api/payment/config

# Get API key
curl http://localhost:8080/api/payment/api-key

# Health check
curl http://localhost:8080/api/payment/health
```

## Stop Vault
```bash
docker-compose down
```

---

## 📁 Key Files

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Vault container config |
| `pom.xml` | Spring Cloud Vault dependencies |
| `application.yml` | Vault connection config |
| `PaymentProperties.java` | @ConfigurationProperties example |
| `PaymentController.java` | REST endpoints |
| `VAULT_SETUP.md` | Full documentation |

---

## 🔑 Important Values

- **Vault URL**: `http://localhost:8200`
- **Root Token**: `dev-root-token`
- **Secrets Path**: `secret/payment-service`
- **Spring Boot Port**: `8080`

---

## 💡 Two Ways to Read Secrets

### 1. @ConfigurationProperties (Recommended)
```java
@Component
@ConfigurationProperties(prefix = "payment")
public class PaymentProperties {
    private String apiKey;
    // ...
}
```

### 2. @Value
```java
@Value("${payment.apiKey}")
private String apiKey;
```

---

See [VAULT_SETUP.md](file:///c:/Users/mdjew/Desktop/rana/voult-demo/VAULT_SETUP.md) for detailed instructions.
