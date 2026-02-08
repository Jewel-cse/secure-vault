# Client Admin Policy Template
# For client administrators who can manage their own secrets
# Replace {{CLIENT_NAME}} with actual client name

# Full access to client-specific secrets
path "secret/data/{{CLIENT_NAME}}/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Manage metadata for client secrets
path "secret/metadata/{{CLIENT_NAME}}/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Delete specific versions of secrets
path "secret/delete/{{CLIENT_NAME}}/*" {
  capabilities = ["update"]
}

# Undelete versions
path "secret/undelete/{{CLIENT_NAME}}/*" {
  capabilities = ["update"]
}

# Destroy versions permanently
path "secret/destroy/{{CLIENT_NAME}}/*" {
  capabilities = ["update"]
}

# Read database credentials
path "database/creds/{{CLIENT_NAME}}-*" {
  capabilities = ["read"]
}

# Read AWS credentials
path "aws/creds/{{CLIENT_NAME}}-*" {
  capabilities = ["read"]
}

# Manage own AppRole
path "auth/approle/role/{{CLIENT_NAME}}" {
  capabilities = ["read"]
}

# Generate new secret IDs for own AppRole
path "auth/approle/role/{{CLIENT_NAME}}/secret-id" {
  capabilities = ["update"]
}

# List own secret ID accessors
path "auth/approle/role/{{CLIENT_NAME}}/secret-id" {
  capabilities = ["list"]
}

# Renew own token
path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Lookup own token
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

# Revoke own token
path "auth/token/revoke-self" {
  capabilities = ["update"]
}

# Health check
path "sys/health" {
  capabilities = ["read"]
}

# Deny access to other clients
path "secret/data/*" {
  capabilities = ["deny"]
}

path "secret/metadata/*" {
  capabilities = ["deny"]
}
