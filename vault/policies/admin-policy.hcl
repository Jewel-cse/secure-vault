# Admin Policy - Full access for Vault administrators
# Path: vault/policies/admin-policy.hcl

# Full access to all secrets engines
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Manage auth methods
path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage policies
path "sys/policies/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage audit devices
path "sys/audit/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage mounts
path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Health check
path "sys/health" {
  capabilities = ["read"]
}

# Seal/unseal operations
path "sys/seal" {
  capabilities = ["update", "sudo"]
}

path "sys/unseal" {
  capabilities = ["update", "sudo"]
}

# Manage tokens
path "auth/token/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage namespaces (Vault Enterprise)
path "sys/namespaces/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Read system configuration
path "sys/config/*" {
  capabilities = ["read", "list"]
}

# Manage leases
path "sys/leases/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
