# Vault Production Configuration
# Storage Backend: AWS S3
# High Availability: Enabled
# TLS: Required

# S3 Storage Backend Configuration
storage "s3" {
  access_key = "env:AWS_ACCESS_KEY_ID"
  secret_key = "env:AWS_SECRET_ACCESS_KEY"
  bucket     = "env:S3_BUCKET_NAME"
  region     = "env:AWS_REGION"
  
  # Enable server-side encryption
  kms_key_id = ""  # Optional: Specify KMS key ID for S3 encryption
  
  # High Availability
  ha_enabled = "true"
  
  # Performance tuning
  max_parallel = "128"
  
  # Path prefix for multi-environment support (optional)
  path = "vault/"
}

# HTTPS Listener
listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/vault/certs/vault-cert.pem"
  tls_key_file  = "/vault/certs/vault-key.pem"
  
  # TLS Configuration
  tls_min_version = "tls12"
  tls_cipher_suites = [
    "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
    "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
    "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
    "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384"
  ]
  
  # Client certificate authentication (optional)
  # tls_require_and_verify_client_cert = true
  # tls_client_ca_file = "/vault/certs/ca-cert.pem"
  
  # Telemetry
  telemetry {
    unauthenticated_metrics_access = false
  }
}

# Cluster Configuration for HA
api_addr      = "env:VAULT_API_ADDR"
cluster_addr  = "env:VAULT_CLUSTER_ADDR"
cluster_name  = "vault-production-cluster"

# UI
ui = true

# Telemetry for Prometheus
telemetry {
  prometheus_retention_time = "30s"
  disable_hostname          = false
  
  # Metrics prefix
  metrics_prefix = "vault"
}

# Seal Configuration
# Option 1: Auto-unseal with AWS KMS (recommended for production)
# Uncomment and configure if you have AWS KMS access
# seal "awskms" {
#   region     = "env:AWS_REGION"
#   kms_key_id = "your-kms-key-id"
#   endpoint   = "https://kms.us-east-1.amazonaws.com"
# }

# Option 2: Shamir seal (default - requires manual unsealing)
# No configuration needed - this is the default

# Disable mlock if running in container without IPC_LOCK capability
# disable_mlock = true

# Log level
log_level = "info"

# Maximum request duration
max_lease_ttl = "768h"
default_lease_ttl = "768h"

# Enable raw endpoint (disable in production for security)
raw_storage_endpoint = false

# Plugin directory
plugin_directory = "/vault/plugins"
