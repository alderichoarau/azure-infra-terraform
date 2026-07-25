output "app_service_url" {
  description = "URL of the Python App Service"
  value       = "https://${module.app_service_python.default_hostname}"
}

output "app_service_hostname" {
  description = "Raw hostname (no scheme) of the Python App Service -- consumed by ../terraform-prometheus's cloud-init (scrape target) via terraform_remote_state, distinct from app_service_url above which includes \"https://\" and isn't a valid Prometheus scrape target as-is."
  value       = module.app_service_python.default_hostname
}

output "action_group_id" {
  description = "ID of the \"team\" Action Group -- consumed by ../terraform-prometheus's alert rule group via terraform_remote_state, so both observability stacks notify the same place without duplicating the Action Group."
  value       = azurerm_monitor_action_group.team.id
}

output "function_app_url" {
  description = "URL of the Function App"
  value       = "https://${module.function_app.default_hostname}"
}

output "container_fqdn" {
  description = "FQDN of the Container Instance"
  value       = "http://${module.container.fqdn}"
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
