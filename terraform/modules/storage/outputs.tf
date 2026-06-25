output "storage_account_name" {
  value = azurerm_storage_account.sa.name
}

output "container_private_url" {
  value = "${azurerm_storage_account.sa.primary_blob_endpoint}${azurerm_storage_container.api_logs.name}"
}

output "container_public_url" {
  value = "${azurerm_storage_account.sa.primary_blob_endpoint}${azurerm_storage_container.api_config.name}"
}
