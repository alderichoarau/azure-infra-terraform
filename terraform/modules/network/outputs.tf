output "vnet_name" {
  description = "Name of the VNet"
  value       = azurerm_virtual_network.vnet.name
}

output "vnet_id" {
  description = "ID of the VNet"
  value       = azurerm_virtual_network.vnet.id
}

output "subnet_frontend_id" {
  description = "ID of subnet-frontend"
  value       = azurerm_subnet.frontend.id
}

output "subnet_backend_id" {
  description = "ID of subnet-backend"
  value       = azurerm_subnet.backend.id
}

output "nsg_name" {
  description = "Name of the NSG attached to subnet-frontend"
  value       = azurerm_network_security_group.nsg.name
}
