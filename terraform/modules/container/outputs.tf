output "fqdn" {
  description = "Public FQDN of the Container Instance"
  value       = azurerm_container_group.aci.fqdn
}

output "ip_address" {
  description = "Public IP address of the Container Instance"
  value       = azurerm_container_group.aci.ip_address
}
