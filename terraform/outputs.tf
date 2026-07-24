output "storage_account_name" {
  description = "Name of the business Storage Account"
  value       = module.storage_shared.storage_account_name
}

output "blob_container_private_url" {
  description = "URL of the private api-logs container"
  value       = module.storage_shared.private_container_url
}

output "blob_container_public_url" {
  description = "Public URL of the api-config container"
  value       = module.storage_shared.public_container_url
}

output "app_service_url" {
  description = "URL of the Python App Service"
  value       = "https://${module.app_service_python.default_hostname}"
}

output "java_app_service_url" {
  description = "URL of the Java Web App (TP Java/Angular — services managés)"
  value       = "https://${azurerm_linux_web_app.java_app.default_hostname}"
}

output "postgres_fqdn" {
  description = "FQDN of the PostgreSQL Flexible Server (private DNS zone — only resolvable/reachable from inside the VNet)"
  value       = azurerm_postgresql_flexible_server.app.fqdn
}

output "redis_hostname" {
  description = "Hostname of the Managed Redis instance (only reachable via its Private Endpoint)"
  value       = azurerm_managed_redis.app.hostname
}

output "key_vault_uri" {
  description = "URI of the Key Vault holding the PostgreSQL connection secrets"
  value       = azurerm_key_vault.app.vault_uri
}

output "java_uploads_container_url" {
  description = "URL of the Java TP's container on the shared Storage Account (module.storage_shared) — access is Azure AD/RBAC-only (see storage-java.tf), not network-restricted"
  value       = "${module.storage_shared.storage_account_name}/${azurerm_storage_container.java_uploads.name}"
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

output "function_app_url" {
  description = "URL of the Function App"
  value       = "https://${module.function_app.default_hostname}"
}

output "container_fqdn" {
  description = "FQDN of the Container Instance"
  value       = "http://${module.container.fqdn}"
}

output "vnet_name" {
  description = "Name of the VNet"
  value       = module.network.vnet_name
}

output "nsg_name" {
  description = "Name of the NSG attached to subnet-frontend"
  value       = module.network.nsg_frontend_name
}

output "law_id" {
  description = "ID of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.law.id
}

output "app_insights_connection_string" {
  description = "Connection string of the App Service's Application Insights"
  value       = azurerm_application_insights.app.connection_string
  sensitive   = true
}

output "func_insights_connection_string" {
  description = "Connection string of the Function App's Application Insights"
  value       = azurerm_application_insights.func.connection_string
  sensitive   = true
}

output "monitor_workspace_id" {
  description = "ID of the Azure Monitor Workspace (managed Prometheus) — use to open Prometheus Explorer in the portal"
  value       = azurerm_monitor_workspace.amw.id
}

output "grafana_endpoint" {
  description = "URL of the Azure Managed Grafana instance"
  value       = azurerm_dashboard_grafana.grafana.endpoint
}

output "monitor_workspace_dce_id" {
  description = "ID of the auto-created Data Collection Endpoint — used for manual `az monitor data-collection endpoint show --ids ...` troubleshooting on the Prometheus VM"
  value       = azurerm_monitor_workspace.amw.default_data_collection_endpoint_id
}

output "monitor_workspace_dcr_id" {
  description = "ID of the auto-created Data Collection Rule — used for manual `az monitor data-collection rule show --ids ...` troubleshooting on the Prometheus VM"
  value       = azurerm_monitor_workspace.amw.default_data_collection_rule_id
}

output "prometheus_vm_public_ip" {
  description = "Public IP of the Prometheus VM — for SSH troubleshooting only, the remote_write pipeline is self-configuring via cloud-init"
  value       = azurerm_public_ip.prometheus_vm.ip_address
}

output "prometheus_vm_ssh_private_key" {
  description = "Terraform-generated SSH private key for the Prometheus VM (admin_username = azureuser). Save it locally with `terraform output -raw prometheus_vm_ssh_private_key > id_rsa && chmod 600 id_rsa` before connecting."
  value       = tls_private_key.prometheus_vm.private_key_openssh
  sensitive   = true
}
