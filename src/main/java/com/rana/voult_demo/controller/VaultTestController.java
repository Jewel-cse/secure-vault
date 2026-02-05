package com.rana.voult_demo.controller;

import com.rana.voult_demo.config.DatabaseConfig;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.vault.core.VaultTemplate;
import org.springframework.vault.support.VaultResponse;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;

/**
 * REST Controller to demonstrate Vault secret access
 */
@RestController
@RequestMapping("/api/vault")
public class VaultTestController {

    @Autowired
    private DatabaseConfig databaseConfig;

    @Autowired(required = false)
    private VaultTemplate vaultTemplate;

    /**
     * Test endpoint to verify Vault connectivity
     * GET http://localhost:8080/api/vault/health
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> health() {
        Map<String, Object> response = new HashMap<>();

        try {
            if (vaultTemplate != null) {
                // Check if secrets are loaded by verifying DatabaseConfig
                boolean secretsLoaded = databaseConfig != null
                        && databaseConfig.getUsername() != null
                        && !databaseConfig.getUsername().isEmpty();

                response.put("status", secretsLoaded ? "UP" : "PARTIAL");
                response.put("vault", "Connected");
                response.put("message", secretsLoaded
                        ? "Successfully connected to Vault and secrets loaded"
                        : "Connected to Vault but secrets not loaded");
                response.put("secretsAvailable", secretsLoaded);
                response.put("databaseConfigLoaded", secretsLoaded);

                // Add debug info
                if (!secretsLoaded) {
                    response.put("debug", Map.of(
                            "username", databaseConfig.getUsername() != null ? "SET" : "NULL",
                            "suggestion", "Check application logs for Vault authentication errors"));
                }

                return ResponseEntity.ok(response);
            } else {
                response.put("status", "DOWN");
                response.put("vault", "Not configured");
                response.put("message", "VaultTemplate is not available");
                response.put("secretsAvailable", false);

                return ResponseEntity.status(503).body(response);
            }
        } catch (Exception e) {
            response.put("status", "ERROR");
            response.put("vault", "Connection failed");
            response.put("message", e.getMessage());
            response.put("error", e.getClass().getSimpleName());
            response.put("secretsAvailable", false);

            return ResponseEntity.status(500).body(response);
        }
    }


    /**
     * Get all secrets from a specific path (for testing)
     * GET http://localhost:8080/api/vault/secrets/database
     * 
     * WARNING: This exposes secrets! Only use for testing!
     */
    @GetMapping("/secrets/database")
    public ResponseEntity<Map<String, Object>> getSecrets() {
        Map<String, Object> response = new HashMap<>();

        try {
            if (vaultTemplate == null) {
                response.put("status", "error");
                response.put("message", "VaultTemplate not available");
                return ResponseEntity.status(503).body(response);
            }

            VaultResponse vaultResponse = vaultTemplate.read("secret/data/payment-service/database");

            if (vaultResponse != null && vaultResponse.getData() != null) {
                response.put("status", "success");
                response.put("path", "secret/payment-service/database");
                response.put("data", vaultResponse.getData().get("data"));
                response.put("metadata", Map.of(
                        "version", vaultResponse.getData().get("metadata")));
            } else {
                response.put("status", "error");
                response.put("message", "No data found at path");
            }

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            response.put("status", "error");
            response.put("message", e.getMessage());
            response.put("error", e.getClass().getSimpleName());

            return ResponseEntity.status(500).body(response);
        }
    }


    /**
     * Get Vault connection info
     * GET http://localhost:8080/api/vault/info
     */
    @GetMapping("/info")
    public ResponseEntity<Map<String, Object>> getVaultInfo() {
        Map<String, Object> response = new HashMap<>();

        response.put("vaultConfigured", vaultTemplate != null);
        response.put("databaseConfigLoaded", databaseConfig != null);
        response.put("authMethod", "AppRole");
        response.put("vaultUri", "http://localhost:8300");
        response.put("secretsPath", "secret/payment-service");

        return ResponseEntity.ok(response);
    }
}
