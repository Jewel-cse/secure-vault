# Production Deployment Guide
## HashiCorp Vault with AWS S3 Backend

This guide walks you through deploying a production-ready HashiCorp Vault cluster with AWS S3 storage backend, supporting 20+ client projects with isolated secrets.

---

## Prerequisites

### System Requirements
- **Windows** (Development): Windows 10/11 with Docker Desktop
- **Ubuntu Server** (Production): Ubuntu 20.04+ with Docker and Docker Compose
- **AWS Account**: With S3 access (no VPC/EC2 required)
- **Resources**: 4GB RAM minimum, 20GB disk space

### Software Requirements
- Docker 20.10+
- Docker Compose 2.0+
- OpenSSL (for certificate generation)
- AWS CLI (configured with credentials)
- Vault CLI (optional, for management)

---

## Quick Start

### 1. Clone and Setup

```bash
cd /path/to/voult-demo

# Copy environment template
cp .env.production.template .env.production

# Edit with your AWS credentials
nano .env.production
```

### 2. Configure AWS S3

Create an S3 bucket for Vault storage:

```bash
# Set your bucket name
export S3_BUCKET_NAME=vault-production-storage-$(date +%s)

# Create bucket
aws s3 mb s3://$S3_BUCKET_NAME --region us-east-1

# Enable versioning (recommended)
aws s3api put-bucket-versioning \
    --bucket $S3_BUCKET_NAME \
    --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
    --bucket $S3_BUCKET_NAME \
    --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }]
    }'

# Update .env.production with bucket name
echo "S3_BUCKET_NAME=$S3_BUCKET_NAME" >> .env.production
```

### 3. Generate TLS Certificates

**On Windows:**
```cmd
cd vault\certs
generate-certs.bat
```

**On Linux/Ubuntu:**
```bash
cd vault/certs
chmod +x generate-certs.sh
./generate-certs.sh
```

### 4. Start Vault Cluster

```bash
# Load environment variables
source .env.production  # Linux
# or
set -a; source .env.production; set +a  # Windows Git Bash

# Start the cluster
docker-compose -f docker-compose.prod.yml up -d

# Check status
docker-compose -f docker-compose.prod.yml ps
```

### 5. Initialize Vault

```bash
# Make script executable (Linux only)
chmod +x scripts/init-vault-prod.sh

# Run initialization
./scripts/init-vault-prod.sh
```

**Important**: This generates unseal keys and root token. Store them securely!

### 6. Access Vault

- **Vault UI**: https://localhost:443/ui
- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090

---

## Windows-Specific Setup

### Install OpenSSL

Download and install from: https://slproweb.com/products/Win32OpenSSL.html

Add to PATH:
```cmd
setx PATH "%PATH%;C:\Program Files\OpenSSL-Win64\bin"
```

### Install AWS CLI

```powershell
msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi
```

### Docker Desktop Configuration

1. Enable WSL 2 backend
2. Allocate at least 4GB RAM
3. Enable file sharing for project directory

### Running Scripts

Use Git Bash or PowerShell:
```powershell
# PowerShell
.\vault\certs\generate-certs.bat
.\scripts\create-client.bat client1
```

---

## Ubuntu Server Setup

### Install Docker

```bash
# Update packages
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### Install AWS CLI

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### Configure AWS Credentials

```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Default region: us-east-1
# Default output format: json
```

### Install Vault CLI (Optional)

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keychains/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keychains/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vault
```

### Firewall Configuration

```bash
# Allow HTTPS
sudo ufw allow 443/tcp

# Allow Grafana (optional, for remote access)
sudo ufw allow 3000/tcp

# Enable firewall
sudo ufw enable
```

---

## Creating Client Projects

### Automated Client Provisioning

**Linux/Ubuntu:**
```bash
chmod +x scripts/create-client.sh
./scripts/create-client.sh client1 admin@client1.com
```

**Windows:**
```cmd
scripts\create-client.bat client1 admin@client1.com
```

This creates:
- Client-specific policies
- AppRole for authentication
- Initial secret structure
- Credentials file in `./clients/`

### Manual Client Creation

```bash
# Set Vault address and token
export VAULT_ADDR=https://localhost:443
export VAULT_TOKEN=<your-root-or-admin-token>

# Create policy
vault policy write client1 - <<EOF
path "secret/data/client1/*" {
  capabilities = ["read", "list"]
}
EOF

# Create AppRole
vault write auth/approle/role/client1 \
    token_ttl=1h \
    token_max_ttl=4h \
    token_policies=client1

# Get credentials
vault read auth/approle/role/client1/role-id
vault write -f auth/approle/role/client1/secret-id
```

---

## High Availability

The setup includes 3 Vault nodes:
- **vault-1** (Active) - Port 8200
- **vault-2** (Standby) - Port 8201
- **vault-3** (Standby) - Port 8202

### Failover Testing

```bash
# Stop active node
docker stop vault-prod-1

# Check status - standby should become active
docker exec vault-prod-2 vault status
```

### Load Balancer

Nginx distributes traffic across all nodes with health checks.

---

## Backup and Recovery

### Create Backup

```bash
chmod +x scripts/backup-vault.sh
./scripts/backup-vault.sh
```

Backups are:
- Compressed with tar.gz
- Encrypted with GPG
- Uploaded to S3 backup bucket
- Stored locally in `./backups/`

### Restore from Backup

```bash
# Download backup from S3
aws s3 cp s3://vault-backups/vault-backup-TIMESTAMP.tar.gz.gpg .

# Decrypt
gpg vault-backup-TIMESTAMP.tar.gz.gpg

# Extract
tar -xzf vault-backup-TIMESTAMP.tar.gz

# Sync to S3
aws s3 sync vault-backup-TIMESTAMP/s3-data/ s3://vault-production-storage/vault/

# Restart Vault
docker-compose -f docker-compose.prod.yml restart
```

---

## Monitoring

### Grafana Dashboards

Access: http://localhost:3000
- Default credentials: admin/admin
- Pre-configured Prometheus datasource
- Import Vault dashboard (ID: 12904)

### Prometheus Metrics

Access: http://localhost:9090
- Vault metrics: `/v1/sys/metrics`
- Query examples:
  - `vault_core_unsealed` - Seal status
  - `vault_runtime_alloc_bytes` - Memory usage
  - `vault_core_handle_request` - Request rate

### Audit Logs

```bash
# View audit logs
docker exec vault-prod-1 tail -f /vault/logs/audit.log

# Search for specific client
docker exec vault-prod-1 grep "client1" /vault/logs/audit.log
```

---

## Security Best Practices

### 1. Unseal Key Management

- Distribute 5 keys to different administrators
- Store in password managers (1Password, LastPass)
- Never store all keys in one location
- Consider using AWS KMS for auto-unseal

### 2. Root Token

```bash
# Revoke root token after setup
vault token revoke <root-token>

# Create admin users instead
vault write auth/userpass/users/admin \
    password=<secure-password> \
    policies=admin
```

### 3. TLS Certificates

For production, use certificates from trusted CA:
- Let's Encrypt (free)
- DigiCert
- AWS Certificate Manager

### 4. Network Security

- Use firewall rules to restrict access
- Enable VPN for remote access
- Use private S3 endpoints if possible

### 5. Regular Audits

```bash
# Review policies
vault policy list
vault policy read <policy-name>

# Review auth methods
vault auth list

# Review active tokens
vault list auth/token/accessors
```

---

## Troubleshooting

### Vault is Sealed

```bash
# Check status
vault status

# Unseal with 3 keys
vault operator unseal <key-1>
vault operator unseal <key-2>
vault operator unseal <key-3>
```

### Cannot Connect to S3

```bash
# Test AWS credentials
aws s3 ls s3://vault-production-storage

# Check Vault logs
docker logs vault-prod-1

# Verify environment variables
docker exec vault-prod-1 env | grep AWS
```

### TLS Certificate Errors

```bash
# Verify certificate
openssl x509 -in vault/certs/vault-cert.pem -text -noout

# Trust CA certificate
# Linux:
sudo cp vault/certs/ca-cert.pem /usr/local/share/ca-certificates/vault-ca.crt
sudo update-ca-certificates

# Windows: Import ca-cert.pem via certmgr.msc
```

### High Memory Usage

```bash
# Check container stats
docker stats

# Restart specific node
docker-compose -f docker-compose.prod.yml restart vault-1
```

---

## Scaling for 20+ Clients

### Resource Planning

- **CPU**: 2-4 cores per Vault node
- **RAM**: 4-8GB per node
- **Storage**: S3 scales automatically
- **Network**: 1Gbps recommended

### Performance Optimization

```hcl
# In vault-prod.hcl
storage "s3" {
  max_parallel = "256"  # Increase for better throughput
}

listener "tcp" {
  max_request_size = "33554432"  # 32MB
}
```

### Client Isolation

Each client gets:
- Dedicated secret path: `secret/client-name/*`
- Isolated AppRole
- Separate policies
- Independent audit trail

---

## Next Steps

1. ✅ Complete initial setup
2. ✅ Create first client namespace
3. ⬜ Integrate with your application
4. ⬜ Setup automated backups (cron job)
5. ⬜ Configure monitoring alerts
6. ⬜ Document disaster recovery procedures
7. ⬜ Train team on Vault operations

---

## Support and Resources

- **HashiCorp Vault Docs**: https://www.vaultproject.io/docs
- **AWS S3 Docs**: https://docs.aws.amazon.com/s3/
- **Docker Docs**: https://docs.docker.com/

For issues, check:
1. Docker logs: `docker logs vault-prod-1`
2. Audit logs: `vault/logs/audit.log`
3. Prometheus metrics: http://localhost:9090
