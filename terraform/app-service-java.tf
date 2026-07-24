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

# subnet-backend (module.network, 10.0.2.0/24) can't be reused here: it comes
# from the shared network registry module with no delegation, and it already
# hosts the Redis/Key Vault Private Endpoints (redis.tf, keyvault.tf). Web App
# regional VNet Integration requires its subnet delegated to
# Microsoft.Web/serverFarms specifically — same "one delegation per subnet"
# constraint already hit for Postgres (subnet-data, database.tf) — so this
# gets its own subnet rather than touching the registry module.
resource "azurerm_subnet" "java_app" {
  name                 = "subnet-java-app"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = module.network.vnet_name
  address_prefixes     = ["10.0.5.0/24"]

  delegation {
    name = "java-app-vnet-integration"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

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

  virtual_network_subnet_id = azurerm_subnet.java_app.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    minimum_tls_version = "1.2"
    application_stack {
      # java_server = "JAVA" means Java SE (embedded server, runs the app's own
      # executable jar) rather than Tomcat/JBoss. All three arguments are now
      # required together, even in this mode.
      java_server         = "JAVA"
      java_server_version = "21"
      java_version        = "21"
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
  # APP_CORS_ALLOWED_ORIGINS: the `cors` block above is App Service's own
  # platform-level CORS (handles preflight before the request even reaches the
  # Java process). But the Spring app also runs its own CORS config
  # (WebConfig.java, bound to app.cors.allowed-origins, default
  # "http://localhost:4200" for local dev) — without overriding it here, the
  # request would pass App Service's CORS check and then get rejected by
  # Spring's. Relaxed binding (app.cors.allowed-origins -> APP_CORS_ALLOWED_ORIGINS)
  # needs no extra Spring profile.
  app_settings = {
    # Local dev's application.yml keeps a "default" profile document with
    # hardcoded localhost values (datasource, Azurite connection string for
    # Blob Storage). Spring's implicit "default" profile activates whenever
    # no profile is explicitly set — without this, that profile would also
    # activate here in prod. Most of its properties are safely overridden by
    # same-named env vars below regardless (env vars outrank profile-bundled
    # properties in Spring's precedence order), but the Blob Storage
    # connection-string has no such override in prod (there's no
    # STORAGE_CONNECTION_STRING app setting, on purpose — prod authenticates
    # via account-name + this Web App's managed identity, not a connection
    # string) — so without deactivating "default" outright, prod would try to
    # reach a local Azurite that doesn't exist. Explicit > implicit either way.
    SPRING_PROFILES_ACTIVE = "prod"

    KEY_VAULT_URI              = azurerm_key_vault.app.vault_uri
    SPRING_DATASOURCE_URL      = "jdbc:postgresql://${azurerm_postgresql_flexible_server.app.fqdn}:5432/${azurerm_postgresql_flexible_server_database.app.name}?sslmode=require"
    SPRING_DATASOURCE_USERNAME = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.postgres_username.versionless_id})"
    SPRING_DATASOURCE_PASSWORD = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.postgres_password.versionless_id})"
    REDIS_HOSTNAME             = azurerm_managed_redis.app.hostname
    REDIS_PORT                 = azurerm_managed_redis.app.default_database[0].port
    REDIS_PASSWORD             = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.redis_access_key.versionless_id})"
    REDIS_SSL_ENABLED          = "true" # Managed Redis default_database.client_protocol defaults to "Encrypted" (TLS) — see redis.tf
    BACKEND_API_KEY            = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.backend_api_key.versionless_id})"
    STORAGE_ACCOUNT_NAME       = module.storage_shared.storage_account_name
    STORAGE_CONTAINER_NAME     = azurerm_storage_container.java_uploads.name
    APP_CORS_ALLOWED_ORIGINS   = "https://${azurerm_static_web_app.angular_frontend.default_host_name}"
  }

  # component tag: lets the backend app repo's CI find this exact Web App by
  # tag (owner + environment + component) rather than hardcoding its name —
  # matters here specifically because this Resource Group also holds the
  # Python TP's App Service (same owner/environment tags, different resource).
  tags = merge(local.tags, { component = "quiz-backend" })
}
