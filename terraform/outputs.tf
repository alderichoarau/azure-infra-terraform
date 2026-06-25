output "storage_account_name" {
  description = "Name of the business Storage Account"
  value       = module.storage.storage_account_name
}

output "blob_container_private_url" {
  description = "URL of the private api-logs container"
  value       = module.storage.container_private_url
}

output "blob_container_public_url" {
  description = "Public URL of the api-config container"
  value       = module.storage.container_public_url
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
  value       = module.network.nsg_name
}
