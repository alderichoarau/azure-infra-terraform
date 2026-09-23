# terraform-runner

VM pour un runner GitHub Actions self-hosted — réduit la dépendance aux minutes `ubuntu-latest`
hébergées par GitHub pour la CI des repos applicatifs (`azure-quiz-backend`/`azure-quiz-frontend`).

Provisioning uniquement : la configuration de la VM (Docker, l'agent runner, le durcissement) est
gérée séparément par [azure-infra-ansible](https://github.com/alderichoarau/azure-infra-ansible),
pas par ce répertoire.

## Pourquoi un répertoire séparé

Une convenance personnelle, pas une dépendance de l'app quiz — appliquer/détruire CE répertoire est
son propre cycle de vie, découplé du reste. N'a de sens que sur la subscription **prod** (le cohort
Simplon partagé sur nonprod n'a aucun usage pour un runner CI personnel).

## Dépendances

Lit `vnet_name` depuis `../terraform-core` (`data.terraform_remote_state.core`) pour poser
`subnet-runner` dans le même VNet — doit donc avoir été appliqué au moins une fois avant ce
répertoire.

## Utilisation

```
cd terraform-runner
terraform init
terraform plan
terraform apply    # crée la VM
...
terraform destroy  # la détruit, sans toucher au reste de l'infra
```

Mêmes secrets/OIDC que les autres répertoires — via le workflow générique
`.github/workflows/deploy-terraform.yml` (`directories=terraform-runner`, `environment=prod`), ou en
local avec `-var="automation_only=true"`.

Après un `apply` réussi, récupère les deux outputs pour `azure-infra-ansible` :

```
terraform output -raw runner_vm_public_ip
terraform output -raw runner_ssh_private_key
```

## Terraform reference

Auto-généré par le hook pre-commit `terraform_docs` (`.terraform-docs.yml`) — ne pas éditer le tableau ci-dessous à la main, il est réécrit au prochain commit touchant un `.tf` de ce répertoire.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.9 |
| azurerm | ~> 5.5 |
| tls | ~> 4.0 |

## Providers

| Name | Version |
| ---- | ------- |
| azurerm | 5.6.0 |
| terraform | n/a |
| tls | 4.4.1 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_linux_virtual_machine.runner](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine) | resource |
| [azurerm_network_interface.runner_vm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface) | resource |
| [azurerm_network_interface_security_group_association.runner_vm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface_security_group_association) | resource |
| [azurerm_network_security_group.runner_vm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_public_ip.runner_vm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |
| [azurerm_subnet.runner](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet_network_security_group_association.runner](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association) | resource |
| [tls_private_key.runner_vm](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [azurerm_resource_group.rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |
| [terraform_remote_state.core](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| automation\_only | Guard against accidental local apply/destroy -- set to true only by the CI pipeline (TF\_VAR\_automation\_only). | `bool` | n/a | yes |
| core\_workspace\_name | HCP Terraform Cloud workspace name of ../terraform-core -- read via terraform\_remote\_state (main.tf) for the VNet name this stack's dedicated subnet attaches to. | `string` | `"azure-quiz-core-alderic-hoarau-nonprod"` | no |
| environment | n/a | `string` | `"nonprod"` | no |
| location | n/a | `string` | `"francecentral"` | no |
| owner | Learner identifier -- must match ../terraform-core's var.owner exactly, both for consistent resource naming and because that's whose Resource Group this stack deploys into. | `string` | n/a | yes |
| resource\_group\_name | Same Resource Group as ../terraform-core -- this stack lives alongside the rest of the learner's infra, not a separate one. | `string` | n/a | yes |
| runner\_admin\_ip\_cidr | CIDR allowed to SSH (22) into the runner VM -- the owner's own IP, not a shared training room's. | `string` | n/a | yes |
| runner\_vm\_size | VM size for the runner VM. Standard\_B2s default (2 vCPU/4GB, burstable, cheapest fit for lint/test/build workloads) -- if this errors with a capacity restriction (B-series has been capacity-restricted on this owner's other subscription in francecentral, see ../terraform-prometheus), fall back to Standard\_D2s\_v3. | `string` | `"Standard_B2s"` | no |
| tags | n/a | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| runner\_ssh\_private\_key | Terraform-generated SSH private key for the runner VM (admin\_username = azureuser). Copy this into azure-infra-ansible's RUNNER\_SSH\_PRIVATE\_KEY secret -- `terraform output -raw runner_ssh_private_key`. |
| runner\_vm\_public\_ip | Public IP of the runner VM -- pass to azure-infra-ansible's run-playbook workflow. |
<!-- END_TF_DOCS -->
