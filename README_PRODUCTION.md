# Production Vault Implementation - README

Production-ready HashiCorp Vault deployment with AWS S3 backend, supporting 20+ client projects with isolated secret management.

---

## 🚀 Features

- ✅ **AWS S3 Storage Backend** - Scalable, durable secret storage
- ✅ **High Availability** - 3-node cluster with automatic failover
- ✅ **Multi-Client Support** - Manage secrets for 20+ client projects
- ✅ **TLS Encryption** - Secure communication with SSL/TLS
- ✅ **AppRole Authentication** - Secure machine-to-machine auth
- ✅ **Monitoring** - Prometheus + Grafana dashboards
- ✅ **Automated Backups** - Encrypted backups to S3
- ✅ **Cross-Platform** - Works on Windows and Ubuntu

---

## 📋 Quick Start

### 1. Prerequisites
- Docker & Docker Compose
- AWS account with S3 access
- OpenSSL (for TLS certificates)

### 2. Setup (15 minutes)

```bash
# 1. Configure AWS S3
aws s3 mb s3://vault-prod-$(date +%s)

# 2. Setup environment
cp .env.production.template .env.production
# Edit .env.production with your AWS credentials

# 3. Generate TLS certificates
cd vault/certs && ./generate-certs.sh

# 4. Start Vault cluster
docker-compose -f docker-compose.prod.yml up -d

# 5. Initialize Vault
./scripts/init-vault-prod.sh

# 6. Create first client
export VAULT_TOKEN=<root-token>
./scripts/create-client.sh client1 admin@client1.com
```

See [QUICK_START_PRODUCTION.md](QUICK_START_PRODUCTION.md) for detailed steps.

---

## 📁 Project Structure

```
voult-demo/
├── docker-compose.prod.yml          # Production Docker Compose
├── .env.production.template         # Environment variables template
├── vault/
│   ├── config/
│   │   └── vault-prod.hcl          # Vault configuration with S3
│   ├── certs/
│   │   ├── generate-certs.sh       # TLS certificate generation (Linux)
│   │   └── generate-certs.bat      # TLS certificate generation (Windows)
│   └── policies/
│       ├── admin-policy.hcl        # Admin access policy
│       ├── client-template-policy.hcl
│       └── client-admin-template-policy.hcl
├── scripts/
│   ├── init-vault-prod.sh          # Initialize Vault cluster
│   ├── create-client.sh            # Create client namespace (Linux)
│   ├── create-client.bat           # Create client namespace (Windows)
│   └── backup-vault.sh             # Backup automation
├── nginx/
│   └── nginx.conf                  # Load balancer configuration
├── monitoring/
│   ├── prometheus.yml              # Metrics collection
│   └── grafana-dashboards/         # Pre-built dashboards
├── docs/
│   ├── PRODUCTION_DEPLOYMENT.md    # Complete deployment guide
│   └── MULTI_CLIENT_GUIDE.md       # Multi-client management
└── src/
    └── main/
        ├── java/.../
        │   ├── config/
        │   │   └── VaultProductionConfig.java
        │   └── service/
        │       └── MultiClientVaultService.java
        └── resources/
            └── application-prod.yml
```

---

## 🏗️ Architecture

```
┌─────────────────┐
│  Client Apps   │
│  (20 clients)  │
└────────┬────────┘
         │ HTTPS
         ▼
┌─────────────────┐
│  Nginx (LB)     │
└────────┬────────┘
         │
    ┌────┴────┬────────┐
    ▼         ▼        ▼
┌────────┐┌────────┐┌────────┐
│Vault-1 ││Vault-2 ││Vault-3 │
│(Active)││(Standby)│(Standby)│
└────┬───┘└────┬───┘└────┬───┘
     │         │         │
     └─────────┴─────────┘
              │
              ▼
     ┌────────────────┐
     │   AWS S3       │
     │  (Encrypted)   │
     └────────────────┘
```

---

## 🔐 Security Features

- **Encryption at Rest**: S3 server-side encryption (SSE-AES256)
- **Encryption in Transit**: TLS 1.2+ with strong cipher suites
- **Access Control**: Policy-based isolation per client
- **Audit Logging**: All operations logged for compliance
- **Shamir Secret Sharing**: 5 unseal keys, threshold of 3
- **Token Auto-Renewal**: Automatic token refresh

---

## 👥 Multi-Client Management

### Create New Client

```bash
./scripts/create-client.sh acme-corp admin@acme.com
```

This creates:
- Isolated secret path: `secret/acme-corp/*`
- AppRole for authentication
- Read-only and admin policies
- Credentials file with Role ID and Secret ID

### Add Secrets

```bash
vault kv put secret/acme-corp/database \
    username=db_user \
    password=SecurePass123! \
    host=db.acme.com

vault kv put secret/acme-corp/api-keys \
    stripe_key=sk_live_xxxxx \
    sendgrid_key=SG.xxxxx
```

See [MULTI_CLIENT_GUIDE.md](docs/MULTI_CLIENT_GUIDE.md) for complete guide.

---

## 🔌 Spring Boot Integration

### Configuration

```yaml
spring:
  cloud:
    vault:
      uri: https://localhost:443
      authentication: APPROLE
      app-role:
        role-id: ${VAULT_ROLE_ID}
        secret-id: ${VAULT_SECRET_ID}
```

### Usage

```java
@Autowired
private MultiClientVaultService vaultService;

// Read database config
DatabaseConfig db = vaultService.getDatabaseConfig("client1");

// Read API keys
Map<String, String> apiKeys = vaultService.getApiKeys("client1");
String stripeKey = apiKeys.get("stripe_key");
```

---

## 📊 Monitoring

- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **Vault UI**: https://localhost:443/ui

### Key Metrics
- Vault seal/unseal status
- Request rate and latency
- Storage backend health
- Authentication failures

---

## 💾 Backup & Recovery

### Create Backup

```bash
./scripts/backup-vault.sh
```

Backups are:
- Compressed with tar.gz
- Encrypted with GPG
- Uploaded to S3 backup bucket

### Restore

```bash
# Download backup
aws s3 cp s3://vault-backups/vault-backup-TIMESTAMP.tar.gz.gpg .

# Decrypt and extract
gpg vault-backup-TIMESTAMP.tar.gz.gpg
tar -xzf vault-backup-TIMESTAMP.tar.gz

# Sync to S3
aws s3 sync vault-backup-TIMESTAMP/s3-data/ s3://vault-prod/vault/
```

---

## 🖥️ Platform Support

### Windows
- ✅ Docker Desktop
- ✅ PowerShell/CMD scripts
- ✅ Self-signed certificate generation
- ✅ Full feature parity

### Ubuntu Server
- ✅ Docker CE
- ✅ Bash scripts
- ✅ Systemd integration
- ✅ Production-ready

---

## 📚 Documentation

- [Quick Start](QUICK_START_PRODUCTION.md) - Get running in 15 minutes
- [Production Deployment](docs/PRODUCTION_DEPLOYMENT.md) - Complete setup guide
- [Multi-Client Guide](docs/MULTI_CLIENT_GUIDE.md) - Managing 20+ clients
- [Dev Mode Setup](DEV_MODE_SETUP.md) - Development environment

---

## 🔧 Troubleshooting

### Vault is Sealed
```bash
vault operator unseal <key-1>
vault operator unseal <key-2>
vault operator unseal <key-3>
```

### Check Logs
```bash
docker logs vault-prod-1
docker exec vault-prod-1 tail -f /vault/logs/audit.log
```

### Health Check
```bash
curl -k https://localhost:443/v1/sys/health
```

---

## 📈 Scaling

Current setup supports:
- **Clients**: 20+ with path-based isolation
- **Secrets**: Unlimited (S3 scales automatically)
- **Requests**: 1000+ req/sec with 3-node cluster
- **Storage**: Petabyte-scale with S3

To scale further:
- Add more Vault nodes
- Increase S3 max_parallel setting
- Use AWS KMS for auto-unseal
- Enable Vault Enterprise for namespaces

---

## 🤝 Support

For issues:
1. Check logs: `docker logs vault-prod-1`
2. Review audit: `vault/logs/audit.log`
3. Consult docs: `docs/`
4. HashiCorp Vault docs: https://www.vaultproject.io/docs

---

## 📝 License

This project is for educational and production use. HashiCorp Vault is licensed under MPL 2.0.

---

## ✅ Production Checklist

- [ ] AWS S3 bucket created with encryption
- [ ] TLS certificates generated
- [ ] Vault cluster initialized
- [ ] Unseal keys distributed securely
- [ ] Root token revoked after setup
- [ ] Admin users created
- [ ] First client provisioned
- [ ] Monitoring dashboards configured
- [ ] Backup automation tested
- [ ] Disaster recovery documented
- [ ] Team trained on operations

---

**Ready to deploy? Start with [QUICK_START_PRODUCTION.md](QUICK_START_PRODUCTION.md)!**
