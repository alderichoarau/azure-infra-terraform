# ──────────────────────────────────────────────────────────────────────────────
# app-service-java.tf — Java backend + its own App Service Plan, both in the
# learner's own Resource Group (data.azurerm_resource_group.rg, main.tf) —
# same RG as Postgres/Redis/Key Vault/the Static Web App, not a separate
# mutualised plan. Simpler to run end-to-end from a single GitHub Actions
# pipeline / single `terraform apply`: Terraform resolves the dependency
# (service_plan_id references the plan below) and creates the plan first,
# the Web App second, automatically — no separate bootstrap step needed.
#
# Deliberately NOT data.azurerm_service_plan.shared (main.tf, used by the
# Python observability TP's app-service.tf) — kept separate from that plan.
# ──────────────────────────────────────────────────────────────────────────────

resource "azurerm_service_plan" "java_app" {
  name                = "plan-java-${var.owner}-tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  os_type             = "Linux"
  sku_name            = var.java_app_plan_sku

  tags = local.tags
}

# ──────────────────────────────────────────────────────────────────────────────
# Network segmentation (cahier des charges §6): outbound VNet Integration on
# subnet-backend lets this app reach Postgres/Redis/Key Vault's Private
# Endpoints; it has no bearing on inbound traffic.
#
# Inbound restriction — option 2, deliberately not a Private Endpoint: Static
# Web App's official "linked backend" proxy needs the backend to stay publicly
# reachable (Microsoft's own docs — SWA's proxy runs outside any customer VNet
# and cannot reach a network-restricted origin), and even without that proxy,
# an Angular SPA calls this API straight from the end user's browser, not from
# the frontend server — so there's no fixed frontend IP/identity to restrict to
# in the first place. Instead: CORS locked to the Static Web App's own origin,
# plus a shared API key (keyvault.tf) the Java code must validate on every
# request. Neither stops a direct curl with the key in hand — see keyvault.tf's
# comment for what this trade-off does and doesn't buy you.
# ──────────────────────────────────────────────────────────────────────────────

resource "azurerm_linux_web_app" "java_app" {
  name                = "app-java-${var.owner}-tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = azurerm_service_plan.java_app.location
  service_plan_id     = azurerm_service_plan.java_app.id
  https_only          = true

  virtual_network_subnet_id = module.network.subnet_backend_id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    minimum_tls_version = "1.2"
    application_stack {
      java_version = "21"
    }

    # Locked to the Static Web App's own origin — no wildcard, no other domain.
    cors {
      allowed_origins     = ["https://${azurerm_static_web_app.angular_frontend.default_host_name}"]
      support_credentials = false
    }
  }

  # SPRING_DATASOURCE_USERNAME/PASSWORD and BACKEND_API_KEY use the
  # "@Microsoft.KeyVault(...)" app setting syntax: App Service resolves them at
  # runtime via this Web App's own managed identity, which is why
  # azurerm_role_assignment.backend_kv_secrets_user (keyvault.tf) grants it
  # "Key Vault Secrets User" — without that role the app starts with the
  # literal unresolved reference string instead of the secret.
  #
  # BACKEND_API_KEY must be checked by the Java code on every incoming request
  # (e.g. a servlet filter rejecting anything without a matching
  # X-Api-Key header) — Terraform only provisions and hands over the value,
  # it cannot enforce the check itself.
  app_settings = {
    KEY_VAULT_URI              = azurerm_key_vault.app.vault_uri
    SPRING_DATASOURCE_URL      = "jdbc:postgresql://${azurerm_postgresql_flexible_server.app.fqdn}:5432/${azurerm_postgresql_flexible_server_database.app.name}?sslmode=require"
    SPRING_DATASOURCE_USERNAME = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.postgres_username.versionless_id})"
    SPRING_DATASOURCE_PASSWORD = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.postgres_password.versionless_id})"
    REDIS_HOSTNAME             = azurerm_managed_redis.app.hostname
    BACKEND_API_KEY            = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.backend_api_key.versionless_id})"
  }

  tags = local.tags
}
