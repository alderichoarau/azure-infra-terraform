output "vnet_name" {
  value = azurerm_virtual_network.vnet.name
}

output "vnet_id" {
  value = azurerm_virtual_network.vnet.id
}

output "subnet_frontend_id" {
  value = azurerm_subnet.frontend.id
}

output "subnet_backend_id" {
  value = azurerm_subnet.backend.id
}

output "nsg_name" {
  value = azurerm_network_security_group.nsg.name
}
