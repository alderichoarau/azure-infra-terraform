# ──────────────────────────────────────────────────────────────────────────────
# keyvault.tf — Key Vault storing the PostgreSQL connection secrets.
#
# TP Java/Angular — piste "services managés" (cahier des charges §2 et §6:
# Key Vault required for DB credentials, reachable only from the backend).
#
# RBAC authorization (not legacy access policies), public access disabled,
# reachable only via the Private Endpoint below.
#
# purge_protection is intentionally OFF. This repo is destroyed/recreated
# regularly (terraform-cleanup.yml runs a full destroy). A purge-protected
# vault stays soft-deleted for up to 90 days and blocks reusing the same name
# on the next apply — acceptable trade-off for production, not for a training
# repo torn down every week.
#
# Gotcha: under RBAC authorization, nobody can read/write secrets by default —
# not even the deployer. azurerm_role_assignment.deployer_kv_secrets_officer
# grants the Terraform principal itself the right to create the secrets below.
# RBAC role assignments also take a little while to propagate through Azure AD;
# without the time_sleep, the first azurerm_key_vault_secret apply intermittently
# 403s right after the role assignment reports "created".
# ──────────────────────────────────────────────────────────────────────────────

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "app" {
  name                = "kv-${replace(var.owner, "-", "")}-tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  enable_rbac_authorization     = true
  purge_protection_enabled      = false
  public_network_access_enabled = false

  tags = local.tags
}

resource "azurerm_private_endpoint" "keyvault" {
  name                = "pe-kv-${var.owner}-tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  subnet_id           = module.network.subnet_backend_id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-kv-${var.owner}-tf"
    private_connection_resource_id = azurerm_key_vault.app.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }
}

# Deployer (the Terraform-executing identity — the CI's OIDC service principal,
# or the caller's own account when running with -var="automation_only=true")
# needs write access to create the secrets below.
resource "azurerm_role_assignment" "deployer_kv_secrets_officer" {
  scope                = azurerm_key_vault.app.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Backend Web App needs read access at runtime to resolve the
# "@Microsoft.KeyVault(...)" app settings in app-service-java.tf.
# Deliberately NOT in the secrets' depends_on chain below — this role assignment
# depends on azurerm_linux_web_app.java_app existing, and the Web App's app
# settings reference the secrets, so making the secrets wait on this role too
# would be a dependency cycle. Read access only matters once the app actually
# starts, which is well after Terraform apply finishes either way.
resource "azurerm_role_assignment" "backend_kv_secrets_user" {
  scope                = azurerm_key_vault.app.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.java_app.identity[0].principal_id
}

resource "time_sleep" "wait_for_deployer_rbac" {
  depends_on      = [azurerm_role_assignment.deployer_kv_secrets_officer]
  create_duration = "30s"
}

resource "azurerm_key_vault_secret" "postgres_host" {
  name         = "postgres-host"
  value        = azurerm_postgresql_flexible_server.app.fqdn
  key_vault_id = azurerm_key_vault.app.id
  depends_on   = [time_sleep.wait_for_deployer_rbac]
}

resource "azurerm_key_vault_secret" "postgres_username" {
  name         = "postgres-username"
  value        = azurerm_postgresql_flexible_server.app.administrator_login
  key_vault_id = azurerm_key_vault.app.id
  depends_on   = [time_sleep.wait_for_deployer_rbac]
}

resource "azurerm_key_vault_secret" "postgres_password" {
  name         = "postgres-password"
  value        = random_password.postgres_admin.result
  key_vault_id = azurerm_key_vault.app.id
  depends_on   = [time_sleep.wait_for_deployer_rbac]
}

resource "azurerm_key_vault_secret" "postgres_connection_string" {
  name         = "postgres-connection-string"
  value        = "postgresql://${azurerm_postgresql_flexible_server.app.administrator_login}:${random_password.postgres_admin.result}@${azurerm_postgresql_flexible_server.app.fqdn}:5432/${azurerm_postgresql_flexible_server_database.app.name}?sslmode=require"
  key_vault_id = azurerm_key_vault.app.id
  depends_on   = [time_sleep.wait_for_deployer_rbac]
}

# ──────────────────────────────────────────────────────────────────────────────
# Backend isolation, option 2 (SWA linked-backend requires a *public* backend —
# see app-service-java.tf for why): CORS locked to the Static Web App's exact
# origin + a shared API key the Angular app sends on every call. This is not
# network isolation — anyone with the URL and the key can still reach the
# backend directly (e.g. via curl) — only the actual header check, implemented
# in the Java code (separate repo), makes this bite. Terraform's job stops at
# generating/storing the key and handing it to both sides via app settings /
# this sensitive output.
# ──────────────────────────────────────────────────────────────────────────────

resource "random_password" "backend_api_key" {
  length  = 40
  special = false # goes straight into an HTTP header value — keep it alnum
}

resource "azurerm_key_vault_secret" "backend_api_key" {
  name         = "backend-api-key"
  value        = random_password.backend_api_key.result
  key_vault_id = azurerm_key_vault.app.id
  depends_on   = [time_sleep.wait_for_deployer_rbac]
}
