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
| [azurerm_container_group.aci](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_group) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| location | Azure region for the container instance | `string` | n/a | yes |
| owner | Learner identifier, used to build unique resource names and tags | `string` | n/a | yes |
| resource\_group\_name | Name of the Resource Group to deploy into | `string` | n/a | yes |
| tags | Tags applied to all resources in this module | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| fqdn | Public FQDN of the Container Instance |
| ip\_address | Public IP address of the Container Instance |
<!-- END_TF_DOCS -->