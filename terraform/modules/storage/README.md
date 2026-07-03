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
| [azurerm_storage_account.sa](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |
| [azurerm_storage_container.api_config](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container) | resource |
| [azurerm_storage_container.api_logs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| location | Azure region for the storage account | `string` | n/a | yes |
| owner | Learner identifier, used to build unique resource names and tags | `string` | n/a | yes |
| resource\_group\_name | Name of the Resource Group to deploy into | `string` | n/a | yes |
| tags | Tags applied to all resources in this module | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| container\_private\_url | URL of the private api-logs container |
| container\_public\_url | Public URL of the api-config container |
| storage\_account\_name | Name of the business Storage Account |
<!-- END_TF_DOCS -->