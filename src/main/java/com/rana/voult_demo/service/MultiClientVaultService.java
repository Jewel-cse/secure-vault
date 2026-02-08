package com.rana.voult_demo.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.vault.core.VaultTemplate;
import org.springframework.vault.support.VaultResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.HashMap;
import java.util.Map;

/**
 * Multi-Client Vault Service
 * Manages secrets for multiple client projects with isolated access
 */
@Service
public class MultiClientVaultService {

    private static final Logger logger = LoggerFactory.getLogger(MultiClientVaultService.class);

    @Autowired
    private VaultTemplate vaultTemplate;

    private final String secretBackend = "secret/data";

    /**
     * Read secret for a specific client
     * 
     * @param clientName Client identifier (e.g., "client1", "acme-corp")
     * @param secretPath Secret path within client namespace (e.g., "database",
     *                   "api-keys")
     * @return Map of secret key-value pairs
     */
    public Map<String, Object> readClientSecret(String clientName, String secretPath) {
        try {
            String fullPath = String.format("%s/%s/%s", secretBackend, clientName, secretPath);
            logger.info("Reading secret from path: {}", fullPath);

            VaultResponse response = vaultTemplate.read(fullPath);

            if (response != null && response.getData() != null) {
                // KV v2 stores data in a nested "data" field
                Object data = response.getData().get("data");
                if (data instanceof Map) {
                    return (Map<String, Object>) data;
                }
            }

            logger.warn("No data found at path: {}", fullPath);
            return new HashMap<>();
        } catch (Exception e) {
            logger.error("Error reading secret for client: {} at path: {}", clientName, secretPath, e);
            throw new RuntimeException("Failed to read secret", e);
        }
    }

    /**
     * Read a specific field from client secret
     * 
     * @param clientName Client identifier
     * @param secretPath Secret path within client namespace
     * @param fieldName  Specific field to retrieve
     * @return Field value as String
     */
    public String readClientSecretField(String clientName, String secretPath, String fieldName) {
        Map<String, Object> secrets = readClientSecret(clientName, secretPath);
        Object value = secrets.get(fieldName);
        return value != null ? value.toString() : null;
    }

    /**
     * Write secret for a specific client (requires admin policy)
     * 
     * @param clientName Client identifier
     * @param secretPath Secret path within client namespace
     * @param secrets    Map of secret key-value pairs
     */
    public void writeClientSecret(String clientName, String secretPath, Map<String, Object> secrets) {
        try {
            String fullPath = String.format("%s/%s/%s", secretBackend, clientName, secretPath);
            logger.info("Writing secret to path: {}", fullPath);

            // KV v2 requires data to be wrapped in a "data" field
            Map<String, Object> wrappedData = new HashMap<>();
            wrappedData.put("data", secrets);

            vaultTemplate.write(fullPath, wrappedData);
            logger.info("Successfully wrote secret for client: {} at path: {}", clientName, secretPath);
        } catch (Exception e) {
            logger.error("Error writing secret for client: {} at path: {}", clientName, secretPath, e);
            throw new RuntimeException("Failed to write secret", e);
        }
    }

    /**
     * Delete secret for a specific client (requires admin policy)
     * 
     * @param clientName Client identifier
     * @param secretPath Secret path within client namespace
     */
    public void deleteClientSecret(String clientName, String secretPath) {
        try {
            String fullPath = String.format("%s/%s/%s", secretBackend, clientName, secretPath);
            logger.info("Deleting secret at path: {}", fullPath);

            vaultTemplate.delete(fullPath);
            logger.info("Successfully deleted secret for client: {} at path: {}", clientName, secretPath);
        } catch (Exception e) {
            logger.error("Error deleting secret for client: {} at path: {}", clientName, secretPath, e);
            throw new RuntimeException("Failed to delete secret", e);
        }
    }

    /**
     * Get database configuration for a client
     * 
     * @param clientName Client identifier
     * @return DatabaseConfig object
     */
    public DatabaseConfig getDatabaseConfig(String clientName) {
        Map<String, Object> dbSecrets = readClientSecret(clientName, "database");

        DatabaseConfig config = new DatabaseConfig();
        config.setUsername(getStringValue(dbSecrets, "username"));
        config.setPassword(getStringValue(dbSecrets, "password"));
        config.setHost(getStringValue(dbSecrets, "host"));
        config.setPort(getIntValue(dbSecrets, "port", 5432));
        config.setDatabase(getStringValue(dbSecrets, "database"));

        return config;
    }

    /**
     * Get API keys for a client
     * 
     * @param clientName Client identifier
     * @return Map of API keys
     */
    public Map<String, String> getApiKeys(String clientName) {
        Map<String, Object> apiKeys = readClientSecret(clientName, "api-keys");
        Map<String, String> result = new HashMap<>();

        apiKeys.forEach((key, value) -> {
            if (value != null) {
                result.put(key, value.toString());
            }
        });

        return result;
    }

    /**
     * Get application configuration for a client
     * 
     * @param clientName Client identifier
     * @return Map of configuration values
     */
    public Map<String, String> getAppConfig(String clientName) {
        Map<String, Object> config = readClientSecret(clientName, "config");
        Map<String, String> result = new HashMap<>();

        config.forEach((key, value) -> {
            if (value != null) {
                result.put(key, value.toString());
            }
        });

        return result;
    }

    // Helper methods
    private String getStringValue(Map<String, Object> map, String key) {
        Object value = map.get(key);
        return value != null ? value.toString() : null;
    }

    private int getIntValue(Map<String, Object> map, String key, int defaultValue) {
        Object value = map.get(key);
        if (value != null) {
            try {
                return Integer.parseInt(value.toString());
            } catch (NumberFormatException e) {
                logger.warn("Invalid integer value for key: {}", key);
            }
        }
        return defaultValue;
    }

    /**
     * Database Configuration POJO
     */
    public static class DatabaseConfig {
        private String username;
        private String password;
        private String host;
        private int port;
        private String database;

        // Getters and Setters
        public String getUsername() {
            return username;
        }

        public void setUsername(String username) {
            this.username = username;
        }

        public String getPassword() {
            return password;
        }

        public void setPassword(String password) {
            this.password = password;
        }

        public String getHost() {
            return host;
        }

        public void setHost(String host) {
            this.host = host;
        }

        public int getPort() {
            return port;
        }

        public void setPort(int port) {
            this.port = port;
        }

        public String getDatabase() {
            return database;
        }

        public void setDatabase(String database) {
            this.database = database;
        }

        public String getJdbcUrl() {
            return String.format("jdbc:postgresql://%s:%d/%s", host, port, database);
        }
    }
}
