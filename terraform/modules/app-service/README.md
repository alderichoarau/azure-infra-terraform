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
| [azurerm_linux_web_app.app](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_web_app) | resource |
| [azurerm_service_plan.plan](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/service_plan) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| owner | Learner identifier, used to build unique resource names and tags | `string` | n/a | yes |
| resource\_group\_name | Name of the Resource Group to deploy into | `string` | n/a | yes |
| service\_plan\_id | ID of the shared App Service Plan the app runs on | `string` | n/a | yes |
| tags | Tags applied to all resources in this module | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| default\_hostname | Default hostname of the App Service |
<!-- END_TF_DOCS -->