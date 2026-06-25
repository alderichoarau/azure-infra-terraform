output "fqdn" {
  value = azurerm_container_group.aci.fqdn
}

output "ip_address" {
  value = azurerm_container_group.aci.ip_address
}
