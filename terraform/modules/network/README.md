<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.9 |
| azurerm | ~> 4.0 |

## Providers

| Name | Version |
| ---- | ------- |
| azurerm | 4.80.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_network_security_group.nsg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_network_security_group.nsg_backend](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_subnet.backend](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet.frontend](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet_network_security_group_association.backend_nsg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association) | resource |
| [azurerm_subnet_network_security_group_association.frontend_nsg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association) | resource |
| [azurerm_virtual_network.vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| location | Azure region for the VNet, subnets and NSGs | `string` | n/a | yes |
| owner | Learner identifier, used to build unique resource names and tags | `string` | n/a | yes |
| resource\_group\_name | Name of the Resource Group to deploy into | `string` | n/a | yes |
| tags | Tags applied to all resources in this module | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| nsg\_name | Name of the NSG attached to subnet-frontend |
| subnet\_backend\_id | ID of subnet-backend |
| subnet\_frontend\_id | ID of subnet-frontend |
| vnet\_id | ID of the VNet |
| vnet\_name | Name of the VNet |
<!-- END_TF_DOCS -->