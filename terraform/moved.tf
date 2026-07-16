# Resource address renames from the local modules/* -> registry module migration.
# Without these, Terraform treats the renamed labels as different resources
# and plans a destroy+create instead of an in-place move.

moved {
  from = module.storage.azurerm_storage_container.api_logs
  to   = module.storage.azurerm_storage_container.private
}

moved {
  from = module.storage.azurerm_storage_container.api_config
  to   = module.storage.azurerm_storage_container.public
}

moved {
  from = module.network.azurerm_network_security_group.nsg
  to   = module.network.azurerm_network_security_group.frontend
}

moved {
  from = module.network.azurerm_network_security_group.nsg_backend
  to   = module.network.azurerm_network_security_group.backend
}

moved {
  from = module.network.azurerm_subnet_network_security_group_association.frontend_nsg
  to   = module.network.azurerm_subnet_network_security_group_association.frontend
}

moved {
  from = module.network.azurerm_subnet_network_security_group_association.backend_nsg
  to   = module.network.azurerm_subnet_network_security_group_association.backend
}
