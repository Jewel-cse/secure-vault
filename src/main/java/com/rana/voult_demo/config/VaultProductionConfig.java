package com.rana.voult_demo.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.vault.authentication.AppRoleAuthentication;
import org.springframework.vault.authentication.AppRoleAuthenticationOptions;
import org.springframework.vault.authentication.ClientAuthentication;
import org.springframework.vault.client.VaultEndpoint;
import org.springframework.vault.config.AbstractVaultConfiguration;
import org.springframework.vault.core.VaultTemplate;
import org.springframework.vault.support.SslConfiguration;

import javax.net.ssl.SSLContext;
import javax.net.ssl.TrustManagerFactory;
import java.io.FileInputStream;
import java.net.URI;
import java.security.KeyStore;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;

/**
 * Enhanced Vault Configuration for Production
 * Supports TLS, AppRole authentication, and multi-client setup
 */
@Configuration
@Profile("prod")
public class VaultProductionConfig extends AbstractVaultConfiguration {

    @Value("${spring.cloud.vault.uri}")
    private String vaultUri;

    @Value("${spring.cloud.vault.app-role.role-id}")
    private String roleId;

    @Value("${spring.cloud.vault.app-role.secret-id}")
    private String secretId;

    @Value("${spring.cloud.vault.ssl.trust-store:}")
    private String trustStorePath;

    @Value("${VAULT_CLIENT_NAME:payment-service}")
    private String clientName;

    @Override
    public VaultEndpoint vaultEndpoint() {
        try {
            URI uri = new URI(vaultUri);
            VaultEndpoint endpoint = VaultEndpoint.from(uri);
            return endpoint;
        } catch (Exception e) {
            throw new RuntimeException("Failed to create Vault endpoint", e);
        }
    }

    @Override
    public ClientAuthentication clientAuthentication() {
        AppRoleAuthenticationOptions options = AppRoleAuthenticationOptions.builder()
                .roleId(AppRoleAuthenticationOptions.RoleId.provided(roleId))
                .secretId(AppRoleAuthenticationOptions.SecretId.provided(secretId))
                .build();

        return new AppRoleAuthentication(options, restOperations());
    }

    @Override
    public SslConfiguration sslConfiguration() {
        if (trustStorePath != null && !trustStorePath.isEmpty()) {
            try {
                // Load custom CA certificate
                KeyStore trustStore = KeyStore.getInstance(KeyStore.getDefaultType());
                trustStore.load(null, null);

                // Load CA certificate from file
                FileInputStream fis = new FileInputStream(trustStorePath);
                CertificateFactory cf = CertificateFactory.getInstance("X.509");
                X509Certificate caCert = (X509Certificate) cf.generateCertificate(fis);
                trustStore.setCertificateEntry("vault-ca", caCert);
                fis.close();

                // Create SSL context with custom trust store
                TrustManagerFactory tmf = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
                tmf.init(trustStore);

                return SslConfiguration.forTrustStore(trustStore, "".toCharArray());
            } catch (Exception e) {
                throw new RuntimeException("Failed to configure SSL", e);
            }
        }

        return SslConfiguration.unconfigured();
    }

    @Bean
    public VaultTemplate vaultTemplate() {
        return new VaultTemplate(vaultEndpoint(), clientAuthentication(), sslConfiguration());
    }

    /**
     * Get the client name for multi-client setup
     */
    public String getClientName() {
        return clientName;
    }
}
