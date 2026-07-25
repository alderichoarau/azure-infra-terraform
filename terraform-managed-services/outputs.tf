output "java_app_service_url" {
  description = "URL of the Java Web App (TP Java/Angular — services managés)"
  value       = "https://${azurerm_linux_web_app.java_app.default_hostname}"
}

output "postgres_fqdn" {
  description = "FQDN of the PostgreSQL Flexible Server (private DNS zone — only resolvable/reachable from inside the VNet, unless postgres_public_access = true)"
  value       = azurerm_postgresql_flexible_server.app.fqdn
}

output "redis_hostname" {
  description = "Hostname of the Managed Redis instance"
  value       = azurerm_managed_redis.app.hostname
}

output "key_vault_uri" {
  description = "URI of the Key Vault holding the PostgreSQL/Redis connection secrets"
  value       = azurerm_key_vault.app.vault_uri
}

output "java_uploads_container_url" {
  description = "URL of the Java TP's container on the shared Storage Account — access is Azure AD/RBAC-only (see storage-java.tf), not network-restricted"
  value       = "${data.terraform_remote_state.core.outputs.storage_account_name}/${azurerm_storage_container.java_uploads.name}"
}

output "angular_frontend_url" {
  description = "URL of the Angular Static Web App"
  value       = "https://${azurerm_static_web_app.angular_frontend.default_host_name}"
}

output "backend_api_key" {
  description = "Shared API key the Angular app must send as X-Api-Key to the Java backend (see app-service-java.tf / keyvault.tf) — wire this into the frontend repo's CI/build as a secret, never commit it."
  value       = random_password.backend_api_key.result
  sensitive   = true
}
