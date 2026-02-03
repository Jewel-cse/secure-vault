# 📁 Project Files Overview

## Configuration Files

### Development
- **docker-compose.yml** - Dev mode Vault (in-memory, auto-unsealed)
- **application.yml** - Dev config (TOKEN authentication)

### Production
- **docker-compose.prod.yml** - Production Vault (persistent storage)
- **application-prod.yml** - Production config (AppRole authentication)
- **vault/config/vault.hcl** - Vault server configuration
- **vault/policies/payment-service-policy.hcl** - Access control policy
- **.env.example** - Environment variables template

## Scripts
- **vault/scripts/init-vault.sh** - Linux/Mac initialization script
- **vault/scripts/init-vault.bat** - Windows initialization script

## Documentation
- **VAULT_SETUP.md** - Development setup guide
- **PRODUCTION_SETUP.md** - Production deployment guide
- **QUICK_START.md** - Quick reference commands
- **README.md** - Project overview

## Java Code
- **PaymentProperties.java** - Configuration properties class
- **PaymentController.java** - REST endpoints demonstrating secret usage

---

## Quick Commands

### Development
```bash
docker-compose up -d
mvn spring-boot:run
```

### Production
```bash
docker-compose -f docker-compose.prod.yml up -d
# Initialize and unseal (first time only)
# Set environment variables
mvn spring-boot:run -Dspring.profiles.active=prod
```

---

See [VAULT_SETUP.md](VAULT_SETUP.md) for development and [PRODUCTION_SETUP.md](PRODUCTION_SETUP.md) for production.
