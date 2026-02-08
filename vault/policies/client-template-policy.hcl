# Client Policy Template
# Replace {{CLIENT_NAME}} with actual client name
# Example: client1, acme-corp, project-alpha

# Read-only access to client-specific secrets
path "secret/data/{{CLIENT_NAME}}/*" {
  capabilities = ["read", "list"]
}

# List secrets in client path
path "secret/metadata/{{CLIENT_NAME}}/*" {
  capabilities = ["list"]
}

# Read database credentials (if using dynamic secrets)
path "database/creds/{{CLIENT_NAME}}-*" {
  capabilities = ["read"]
}

# Read AWS credentials (if using AWS secrets engine)
path "aws/creds/{{CLIENT_NAME}}-*" {
  capabilities = ["read"]
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

# Health check (for monitoring)
path "sys/health" {
  capabilities = ["read"]
}

# Deny access to other clients' secrets
path "secret/data/*" {
  capabilities = ["deny"]
}

path "secret/metadata/*" {
  capabilities = ["deny"]
}
