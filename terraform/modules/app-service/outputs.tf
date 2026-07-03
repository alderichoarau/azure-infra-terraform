output "default_hostname" {
  description = "Default hostname of the App Service"
  value       = azurerm_linux_web_app.app.default_hostname
}
