output "default_hostname" {
  description = "Default hostname of the Function App"
  value       = azurerm_linux_function_app.fn.default_hostname
}

output "function_storage_name" {
  description = "Name of the storage account dedicated to the Function App"
  value       = azurerm_storage_account.fn_storage.name
}
