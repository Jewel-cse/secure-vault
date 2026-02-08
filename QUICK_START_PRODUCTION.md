# Quick Start Guide - Production Vault

Get your production Vault cluster running in 15 minutes!

---

## Prerequisites Checklist

- [ ] Docker and Docker Compose installed
- [ ] AWS account with S3 access
- [ ] AWS CLI configured with credentials
- [ ] OpenSSL installed (for certificates)

---

## Step 1: Configure AWS S3 (5 minutes)

```bash
# Create S3 bucket
export S3_BUCKET=vault-prod-$(date +%s)
aws s3 mb s3://$S3_BUCKET --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket $S3_BUCKET \
    --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
    --bucket $S3_BUCKET \
    --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }]
    }'
```

---

## Step 2: Setup Environment (2 minutes)

```bash
# Copy template
cp .env.production.template .env.production

# Edit with your values
nano .env.production
```

Update these values:
```bash
AWS_ACCESS_KEY_ID=your-key-id
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_REGION=us-east-1
S3_BUCKET_NAME=vault-prod-1234567890
```

---

## Step 3: Generate TLS Certificates (3 minutes)

**Windows:**
```cmd
cd vault\certs
generate-certs.bat
```

**Linux/Ubuntu:**
```bash
cd vault/certs
chmod +x generate-certs.sh
./generate-certs.sh
```

---

## Step 4: Start Vault Cluster (2 minutes)

```bash
# Load environment
source .env.production  # Linux
# or use: set -a; source .env.production; set +a

# Start cluster
docker-compose -f docker-compose.prod.yml up -d

# Verify all containers are running
docker-compose -f docker-compose.prod.yml ps
```

Expected output: 6 containers running (vault-1, vault-2, vault-3, nginx, prometheus, grafana)

---

## Step 5: Initialize Vault (3 minutes)

```bash
# Set Vault address
export VAULT_ADDR=https://localhost:443
export VAULT_SKIP_VERIFY=true  # Only for self-signed certs

# Initialize
chmod +x scripts/init-vault-prod.sh
./scripts/init-vault-prod.sh
```

**IMPORTANT**: Save the generated `vault-keys-*.txt` file securely!

---

## Step 6: Create Your First Client (2 minutes)

```bash
# Set root token from initialization
export VAULT_TOKEN=<root-token-from-step-5>

# Create client
chmod +x scripts/create-client.sh
./scripts/create-client.sh client1 admin@client1.com
```

Credentials saved to: `./clients/client1-credentials.txt`

---

## Step 7: Add Secrets (1 minute)

```bash
# Add database credentials
vault kv put secret/client1/database \
    username=db_user \
    password=SecurePass123! \
    host=db.example.com \
    port=5432 \
    database=production_db

# Add API keys
vault kv put secret/client1/api-keys \
    stripe_key=sk_live_xxxxx \
    sendgrid_key=SG.xxxxx
```

---

## Step 8: Test Access (2 minutes)

```bash
# Read secret
vault kv get secret/client1/database

# Test with AppRole (from credentials file)
vault write auth/approle/login \
    role_id=<role-id> \
    secret_id=<secret-id>
```

---

## Access Points

- **Vault UI**: https://localhost:443/ui
- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090

---

## Next Steps

1. ✅ Vault is running!
2. ⬜ Integrate with your Spring Boot application
3. ⬜ Setup automated backups
4. ⬜ Create remaining 19 clients
5. ⬜ Configure monitoring alerts

---

## Troubleshooting

### Vault is sealed
```bash
vault operator unseal <key-1>
vault operator unseal <key-2>
vault operator unseal <key-3>
```

### Cannot connect to S3
```bash
# Test AWS credentials
aws s3 ls s3://$S3_BUCKET_NAME

# Check Vault logs
docker logs vault-prod-1
```

### TLS certificate errors
```bash
# Trust CA certificate
# Linux:
sudo cp vault/certs/ca-cert.pem /usr/local/share/ca-certificates/vault-ca.crt
sudo update-ca-certificates

# Windows: Import via certmgr.msc
```

---

## Windows-Specific Commands

```cmd
REM Generate certificates
cd vault\certs
generate-certs.bat

REM Create client
scripts\create-client.bat client1 admin@client1.com

REM Set environment
set VAULT_ADDR=https://localhost:443
set VAULT_SKIP_VERIFY=true
```

---

## Ubuntu Server Commands

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Then follow steps 1-8 above
```

---

## For Help

- Check logs: `docker logs vault-prod-1`
- View audit: `docker exec vault-prod-1 tail -f /vault/logs/audit.log`
- Read docs: `docs/PRODUCTION_DEPLOYMENT.md`
