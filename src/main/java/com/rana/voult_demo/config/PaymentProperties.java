package com.rana.voult_demo.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * Configuration properties class that reads secrets from HashiCorp Vault.
 * 
 * Vault path: secret/payment-service
 * 
 * This class automatically binds to properties stored in Vault under the
 * application's default context (payment-service).
 */
@Component
@ConfigurationProperties(prefix = "payment")
public class PaymentProperties {

    private String apiKey;
    private String merchantId;
    private String webhookSecret;

    // Getters and Setters
    public String getApiKey() {
        return apiKey;
    }

    public void setApiKey(String apiKey) {
        this.apiKey = apiKey;
    }

    public String getMerchantId() {
        return merchantId;
    }

    public void setMerchantId(String merchantId) {
        this.merchantId = merchantId;
    }

    public String getWebhookSecret() {
        return webhookSecret;
    }

    public void setWebhookSecret(String webhookSecret) {
        this.webhookSecret = webhookSecret;
    }
}
