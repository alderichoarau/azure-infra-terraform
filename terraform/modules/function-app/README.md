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
| [azurerm_linux_function_app.fn](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_function_app) | resource |
| [azurerm_role_assignment.fn_storage_blob](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_storage_account.fn_storage](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| location | Azure region for the Function App and its dedicated storage account | `string` | n/a | yes |
| owner | Learner identifier, used to build unique resource names and tags | `string` | n/a | yes |
| resource\_group\_name | Name of the Resource Group to deploy into | `string` | n/a | yes |
| service\_plan\_id | ID of the shared App Service Plan the Function App runs on | `string` | n/a | yes |
| tags | Tags applied to all resources in this module | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| default\_hostname | Default hostname of the Function App |
| function\_storage\_name | Name of the storage account dedicated to the Function App |
<!-- END_TF_DOCS -->