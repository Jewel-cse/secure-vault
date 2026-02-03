# Vault Server Configuration for Production

# Storage backend - File storage for simplicity
# For production HA, consider Consul or Integrated Storage (Raft)
storage "file" {
  path = "/vault/file"
}

# HTTP listener
listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_disable   = 1
  
  # For production with TLS, use:
  # tls_disable   = 0
  # tls_cert_file = "/vault/certs/vault.crt"
  # tls_key_file  = "/vault/certs/vault.key"
}

# API and Cluster addresses
api_addr      = "http://0.0.0.0:8200"
cluster_addr  = "http://0.0.0.0:8201"

# Enable UI
ui = true

# Disable mlock for containerized environments
# In production on bare metal, remove this
disable_mlock = true

# Log level
log_level = "info"

# Maximum lease TTL
max_lease_ttl = "768h"

# Default lease TTL
default_lease_ttl = "168h"
