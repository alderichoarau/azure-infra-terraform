output "storage_account_name" {
  description = "Name of the business Storage Account"
  value       = module.storage.storage_account_name
}

output "blob_container_private_url" {
  description = "URL of the private api-logs container"
  value       = module.storage.private_container_url
}

output "blob_container_public_url" {
  description = "Public URL of the api-config container"
  value       = module.storage.public_container_url
}

output "app_service_url" {
  description = "URL of the App Service"
  value       = "https://${module.app_service.default_hostname}"
}

output "function_app_url" {
  description = "URL of the Function App"
  value       = "https://${module.function_app.default_hostname}"
}

output "static_web_app_url" {
  description = "URL of the Static Web App"
  value       = "https://${azurerm_static_web_app.stapp.default_host_name}"
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

output "prometheus_vm_public_ip" {
  description = "Public IP of the Prometheus VM — for SSH troubleshooting only, the remote_write pipeline is self-configuring via cloud-init"
  value       = azurerm_public_ip.prometheus_vm.ip_address
}

output "prometheus_vm_ssh_private_key" {
  description = "Terraform-generated SSH private key for the Prometheus VM (admin_username = azureuser). Save it locally with `terraform output -raw prometheus_vm_ssh_private_key > id_rsa && chmod 600 id_rsa` before connecting."
  value       = tls_private_key.prometheus_vm.private_key_openssh
  sensitive   = true
}
