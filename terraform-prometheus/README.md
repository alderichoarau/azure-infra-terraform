# terraform-prometheus

VM Prometheus + Azure Monitor Workspace (Prometheus managé) + Grafana managé —
la partie la plus chère de ce repo, extraite dans son propre state pour ne
tourner que lorsqu'on en a explicitement besoin.

## Pourquoi un répertoire séparé plutôt que le `count = var.enable_prometheus_stack ? 1 : 0` d'avant

Avant cette extraction, tout ce stack vivait dans l'ancien `terraform/` monolithique
derrière un flag booléen appliqué resource par resource. Ça marchait, mais chaque
`terraform apply`/`destroy` du reste de l'infra repassait par ce même state,
avec le risque de toucher (ou d'oublier de basculer) ce flag. Un répertoire
séparé rend la séparation structurelle : appliquer ou détruire CE répertoire
est maintenant le seul toggle qui existe.

## Dépendances

Ce stack lit des valeurs qu'il ne possède pas, via deux `terraform_remote_state` distincts (`main.tf`) :

- `../terraform-core` (`data.terraform_remote_state.core`) — `vnet_name`, pour poser `subnet-prometheus` dans le même VNet
- `../terraform-python` (`data.terraform_remote_state.python`) — `app_service_hostname` (cible de scrape) et `action_group_id` (pour que ses alertes notifient le même Action Group que `observability.tf`)

Les deux doivent donc avoir été appliqués au moins une fois avant ce répertoire.

## Utilisation

```
cd terraform-prometheus
terraform init
terraform plan
terraform apply    # démarre tout le stack (VM + Grafana + Prometheus managé)
...
terraform destroy  # l'éteint complètement, sans toucher au reste de l'infra
```

Mêmes secrets/OIDC que les autres répertoires — via le workflow générique
`.github/workflows/deploy-terraform.yml` (`directories=terraform-prometheus`),
ou en local avec `-var="automation_only=true"`.

## Terraform reference

Auto-généré par le hook pre-commit `terraform_docs` (`.terraform-docs.yml`) — ne pas éditer le tableau ci-dessous à la main, il est réécrit au prochain commit touchant un `.tf` de ce répertoire.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.9 |
| azurerm | ~> 4.60 |
| tls | ~> 4.0 |

## Providers

| Name | Version |
| ---- | ------- |
| azurerm | 4.81.0 |
| terraform | n/a |
| tls | 4.3.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_dashboard_grafana.grafana](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/dashboard_grafana) | resource |
| [azurerm_linux_virtual_machine.prometheus](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine) | resource |
| [azurerm_monitor_alert_prometheus_rule_group.alerte_erreurs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_alert_prometheus_rule_group) | resource |
| [azurerm_monitor_workspace.amw](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_workspace) | resource |
| [azurerm_network_interface.prometheus_vm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface) | resource |
| [azurerm_network_interface_security_group_association.prometheus_vm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface_security_group_association) | resource |
| [azurerm_network_security_group.prometheus_vm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_public_ip.prometheus_vm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |
| [azurerm_role_assignment.grafana_monitoring_reader](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.prometheus_dce_reader](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.prometheus_dcr_reader](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.prometheus_publisher](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_subnet.prometheus](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet_network_security_group_association.prometheus](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association) | resource |
| [tls_private_key.prometheus_vm](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [azurerm_resource_group.rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |
| [terraform_remote_state.core](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |
| [terraform_remote_state.python](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| automation\_only | Guard against accidental local apply/destroy -- set to true only by the CI pipeline (TF\_VAR\_automation\_only). | `bool` | n/a | yes |
| core\_workspace\_name | HCP Terraform Cloud workspace name of ../terraform-core -- read via terraform\_remote\_state (main.tf) for the VNet name this stack's dedicated subnet attaches to. | `string` | `"azure-core-alderic-hoarau"` | no |
| environment | n/a | `string` | `"nonprod"` | no |
| location | n/a | `string` | `"francecentral"` | no |
| owner | Learner identifier -- must match ../terraform-core's var.owner exactly, both for consistent resource naming and because that's whose Resource Group this stack deploys into. | `string` | n/a | yes |
| prometheus\_vm\_size | VM size for the Prometheus VM. Standard\_D2s\_v3 default -- B-series sizes were found capacity-restricted on this subscription in francecentral. | `string` | `"Standard_D2s_v3"` | no |
| python\_workspace\_name | HCP Terraform Cloud workspace name of ../terraform-python -- read via terraform\_remote\_state (main.tf) for the Python App Service's hostname (scrape target) and the shared "team" Action Group's ID (so alerts land in the same place as observability.tf's, no duplicate Action Group). | `string` | `"azure-python-alderic-hoarau"` | no |
| resource\_group\_name | Same Resource Group as ../terraform-core -- this stack lives alongside the rest of the learner's infra, not a separate one. | `string` | n/a | yes |
| tags | n/a | `map(string)` | `{}` | no |
| trainer\_ip\_cidr | CIDR autorisé en SSH (22) sur la VM Prometheus. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| grafana\_endpoint | URL of the Azure Managed Grafana instance. |
| monitor\_workspace\_dce\_id | ID of the auto-created Data Collection Endpoint — used for manual `az monitor data-collection endpoint show --ids ...` troubleshooting on the Prometheus VM. |
| monitor\_workspace\_dcr\_id | ID of the auto-created Data Collection Rule — used for manual `az monitor data-collection rule show --ids ...` troubleshooting on the Prometheus VM. |
| monitor\_workspace\_id | ID of the Azure Monitor Workspace (managed Prometheus) — use to open Prometheus Explorer in the portal. |
| prometheus\_vm\_public\_ip | Public IP of the Prometheus VM — for SSH troubleshooting only, the remote\_write pipeline is self-configuring via cloud-init. |
| prometheus\_vm\_ssh\_private\_key | Terraform-generated SSH private key for the Prometheus VM (admin\_username = azureuser). Save it locally with `terraform output -raw prometheus_vm_ssh_private_key > id_rsa && chmod 600 id_rsa` before connecting. |
<!-- END_TF_DOCS -->
