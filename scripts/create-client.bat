@echo off
REM Create Client Namespace Script (Windows)
REM Provisions a new client with isolated secrets and AppRole authentication

setlocal enabledelayedexpansion

REM Check if client name is provided
if "%~1"=="" (
    echo ❌ Error: Client name is required
    echo Usage: %~nx0 ^<client-name^> [admin-email]
    echo Example: %~nx0 acme-corp admin@acme.com
    exit /b 1
)

set CLIENT_NAME=%~1
set ADMIN_EMAIL=%~2

REM Vault configuration
if "%VAULT_ADDR%"=="" set VAULT_ADDR=https://localhost:443
if "%VAULT_TOKEN%"=="" (
    echo ⚠️  VAULT_TOKEN not set. Please provide root or admin token:
    set /p VAULT_TOKEN=
)

echo.
echo 🚀 Creating client namespace for: %CLIENT_NAME%
echo.

REM Step 1: Create client-specific policy
echo 📝 Step 1: Creating client policy...
set POLICY_FILE=%TEMP%\%CLIENT_NAME%-policy.hcl

(
echo # Client Policy for %CLIENT_NAME%
echo # Read-only access to client-specific secrets
echo.
echo path "secret/data/%CLIENT_NAME%/*" {
echo   capabilities = ["read", "list"]
echo }
echo.
echo path "secret/metadata/%CLIENT_NAME%/*" {
echo   capabilities = ["list"]
echo }
echo.
echo path "database/creds/%CLIENT_NAME%-*" {
echo   capabilities = ["read"]
echo }
echo.
echo path "auth/token/renew-self" {
echo   capabilities = ["update"]
echo }
echo.
echo path "auth/token/lookup-self" {
echo   capabilities = ["read"]
echo }
echo.
echo path "sys/health" {
echo   capabilities = ["read"]
echo }
) > "%POLICY_FILE%"

vault policy write %CLIENT_NAME% "%POLICY_FILE%"
del /f /q "%POLICY_FILE%"
echo ✅ Policy created: %CLIENT_NAME%

REM Step 2: Create client admin policy
echo 📝 Step 2: Creating client admin policy...
set ADMIN_POLICY_FILE=%TEMP%\%CLIENT_NAME%-admin-policy.hcl

(
echo # Client Admin Policy for %CLIENT_NAME%
echo # Full CRUD access to client-specific secrets
echo.
echo path "secret/data/%CLIENT_NAME%/*" {
echo   capabilities = ["create", "read", "update", "delete", "list"]
echo }
echo.
echo path "secret/metadata/%CLIENT_NAME%/*" {
echo   capabilities = ["create", "read", "update", "delete", "list"]
echo }
echo.
echo path "secret/delete/%CLIENT_NAME%/*" {
echo   capabilities = ["update"]
echo }
echo.
echo path "auth/approle/role/%CLIENT_NAME%/secret-id" {
echo   capabilities = ["update", "list"]
echo }
echo.
echo path "auth/token/renew-self" {
echo   capabilities = ["update"]
echo }
echo.
echo path "sys/health" {
echo   capabilities = ["read"]
echo }
) > "%ADMIN_POLICY_FILE%"

vault policy write %CLIENT_NAME%-admin "%ADMIN_POLICY_FILE%"
del /f /q "%ADMIN_POLICY_FILE%"
echo ✅ Admin policy created: %CLIENT_NAME%-admin

REM Step 3: Create AppRole
echo 📝 Step 3: Creating AppRole for application...
vault write auth/approle/role/%CLIENT_NAME% token_ttl=1h token_max_ttl=4h token_policies=%CLIENT_NAME% bind_secret_id=true secret_id_ttl=0 secret_id_num_uses=0
echo ✅ AppRole created: %CLIENT_NAME%

REM Step 4: Get Role ID
echo 📝 Step 4: Retrieving Role ID...
for /f "tokens=*" %%i in ('vault read -field^=role_id auth/approle/role/%CLIENT_NAME%/role-id') do set ROLE_ID=%%i
echo ✅ Role ID: %ROLE_ID%

REM Step 5: Generate Secret ID
echo 📝 Step 5: Generating Secret ID...
for /f "tokens=*" %%i in ('vault write -field^=secret_id -f auth/approle/role/%CLIENT_NAME%/secret-id') do set SECRET_ID=%%i
echo ✅ Secret ID generated

REM Step 6: Create initial secret structure
echo 📝 Step 6: Creating initial secret structure...
vault kv put secret/%CLIENT_NAME%/config environment=production created_at=%date%-%time% admin_email=%ADMIN_EMAIL%
vault kv put secret/%CLIENT_NAME%/database username="" password="" host="" port="" database="" note="Update these values"
vault kv put secret/%CLIENT_NAME%/api-keys note="Add your API keys here"
echo ✅ Initial secret structure created

REM Step 7: Create credentials file
echo 📝 Step 7: Generating credentials file...
if not exist ".\clients" mkdir ".\clients"
set CREDS_FILE=.\clients\%CLIENT_NAME%-credentials.txt

(
echo ========================================
echo Client: %CLIENT_NAME%
echo Created: %date% %time%
echo ========================================
echo.
echo VAULT CONFIGURATION
echo -------------------
echo Vault Address: %VAULT_ADDR%
echo Client Name: %CLIENT_NAME%
echo.
echo APPLICATION CREDENTIALS ^(AppRole^)
echo ---------------------------------
echo Role ID: %ROLE_ID%
echo Secret ID: %SECRET_ID%
echo.
echo ⚠️  IMPORTANT: Keep these credentials secure!
echo ⚠️  Secret ID is shown only once. Store it safely.
echo.
echo POLICIES
echo --------
echo - %CLIENT_NAME%: Read-only access to secrets
echo - %CLIENT_NAME%-admin: Full CRUD access to secrets
echo.
echo SECRET PATHS
echo ------------
echo - secret/%CLIENT_NAME%/config
echo - secret/%CLIENT_NAME%/database
echo - secret/%CLIENT_NAME%/api-keys
echo.
echo VAULT CLI COMMANDS
echo ------------------
echo # Login with AppRole
echo vault write auth/approle/login role_id=%ROLE_ID% secret_id=%SECRET_ID%
echo.
echo # Read a secret
echo vault kv get secret/%CLIENT_NAME%/database
echo.
echo # Write a secret ^(requires admin policy^)
echo vault kv put secret/%CLIENT_NAME%/api-keys stripe_key=sk_test_xxx
echo.
echo ========================================
) > "%CREDS_FILE%"

echo ✅ Credentials saved to: %CREDS_FILE%

REM Summary
echo.
echo ========================================
echo 🎉 Client provisioning complete!
echo ========================================
echo.
echo Client Name: %CLIENT_NAME%
echo Policy: %CLIENT_NAME%
echo Admin Policy: %CLIENT_NAME%-admin
echo AppRole: %CLIENT_NAME%
echo Credentials File: %CREDS_FILE%
echo.
echo ⚠️  Next Steps:
echo 1. Review and update secrets in: secret/%CLIENT_NAME%/
echo 2. Securely share credentials file with client
echo 3. Delete credentials file after sharing
echo 4. Rotate Secret ID after client confirms setup
echo.

endlocal
