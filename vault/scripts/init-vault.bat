@echo off
REM Vault Production Initialization Script for Windows
REM Run this script ONCE after starting Vault for the first time

echo ==========================================
echo Vault Production Initialization
echo ==========================================

REM Wait for Vault to start
echo Waiting for Vault to start...
timeout /t 5 /nobreak >nul

REM Initialize Vault (only run once!)
echo Initializing Vault...
docker exec vault-prod vault operator init -key-shares=5 -key-threshold=3 > vault-keys.txt

echo.
echo [SUCCESS] Vault initialized!
echo [WARNING] vault-keys.txt contains your unseal keys and root token
echo [WARNING] Store this file securely and NEVER commit it to git!
echo.

REM Parse vault-keys.txt to extract keys and token
REM Note: This is a simplified version. For production, use PowerShell or manual extraction

echo Please manually unseal Vault using the keys from vault-keys.txt
echo.
echo Run these commands with your unseal keys:
echo   docker exec vault-prod vault operator unseal [KEY1]
echo   docker exec vault-prod vault operator unseal [KEY2]
echo   docker exec vault-prod vault operator unseal [KEY3]
echo.
echo Then run: init-vault-step2.bat
echo.

pause
