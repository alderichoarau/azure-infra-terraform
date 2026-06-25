output "default_hostname" {
  value = azurerm_linux_function_app.fn.default_hostname
}

output "function_storage_name" {
  value = azurerm_storage_account.fn_storage.name
}
