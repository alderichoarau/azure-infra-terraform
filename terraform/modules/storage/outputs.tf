output "storage_account_name" {
  description = "Name of the business Storage Account"
  value       = azurerm_storage_account.sa.name
}

output "container_private_url" {
  description = "URL of the private api-logs container"
  value       = "${azurerm_storage_account.sa.primary_blob_endpoint}${azurerm_storage_container.api_logs.name}"
}

output "container_public_url" {
  description = "Public URL of the api-config container"
  value       = "${azurerm_storage_account.sa.primary_blob_endpoint}${azurerm_storage_container.api_config.name}"
}
