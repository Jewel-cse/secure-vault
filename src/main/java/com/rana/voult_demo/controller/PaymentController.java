package com.rana.voult_demo.controller;

import com.rana.voult_demo.config.PaymentProperties;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;

/**
 * REST Controller demonstrating how to read secrets from HashiCorp Vault.
 * 
 * This controller shows two approaches:
 * 1. Using @Value annotation for individual properties
 * 2. Using @ConfigurationProperties via PaymentProperties class
 */
@RestController
@RequestMapping("/api/payment")
public class PaymentController {

    private final PaymentProperties paymentProperties;

    // Example using @Value annotation
    @Value("${payment.apiKey:default-api-key}")
    private String apiKeyFromValue;

    public PaymentController(PaymentProperties paymentProperties) {
        this.paymentProperties = paymentProperties;
    }

    /**
     * Endpoint to retrieve all payment configuration from Vault.
     * 
     * @return Map containing all payment secrets
     */
    @GetMapping("/config")
    public Map<String, String> getPaymentConfig() {
        Map<String, String> config = new HashMap<>();
        config.put("apiKey", paymentProperties.getApiKey());
        config.put("merchantId", paymentProperties.getMerchantId());
        config.put("webhookSecret", paymentProperties.getWebhookSecret());
        return config;
    }

    /**
     * Endpoint demonstrating @Value annotation usage.
     * 
     * @return Map containing API key retrieved via @Value
     */
    @GetMapping("/api-key")
    public Map<String, String> getApiKey() {
        Map<String, String> response = new HashMap<>();
        response.put("apiKey", apiKeyFromValue);
        response.put("source", "Retrieved using @Value annotation");
        return response;
    }

    /**
     * Health check endpoint.
     * 
     * @return Status message
     */
    @GetMapping("/health")
    public Map<String, String> health() {
        Map<String, String> response = new HashMap<>();
        response.put("status", "UP");
        response.put("message", "Payment service is running with Vault integration");
        return response;
    }
}
