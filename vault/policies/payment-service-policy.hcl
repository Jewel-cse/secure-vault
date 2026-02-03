# Policy for payment-service application
# This policy grants read-only access to payment-service secrets

# Allow reading secrets from payment-service path
path "secret/data/payment-service/*" {
  capabilities = ["read"]
}

# Allow listing secrets in payment-service path
path "secret/metadata/payment-service/*" {
  capabilities = ["list"]
}

# Deny all other paths
path "secret/*" {
  capabilities = ["deny"]
}

# Allow token renewal
path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Allow token lookup
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
