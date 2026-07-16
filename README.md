# azure-infra-terraform

Azure infrastructure provisioned with Terraform — PRF2026 training context.

Terraform mirror of the [azure-infra-cli](https://github.com/hoaraualderic/azure-infra-cli) project (Bash scripts).

## Last analysis

[![Terraform CI](https://github.com/alderichoarau/azure-infra-terraform/actions/workflows/ci.yml/badge.svg)](https://github.com/alderichoarau/azure-infra-terraform/actions/workflows/ci.yml)

## Deployed resources

| Resource | Generated name | Description |
| --- | --- | --- |
| Storage Account | `st<owner>tf` | Business storage — `api-logs` container (private) and `api-config` container (public) |
| App Service | `app-<owner>-tf` | Python application on the shared plan |
| App Service (secondary) | `app-<owner>-secondary-tf` | Extra App Service used only to exercise Infracost cost estimation on PRs |
| Function App | `fn-<owner>-tf` | Python Azure Function + dedicated storage |
| Static Web App | `stapp-<owner>-tf` | Static site (Free tier) |
| Container Instance | `aci-<owner>-tf` | nginx:1.27-alpine, publicly exposed |
| VNet + subnets + NSG | `vnet-<owner>-tf` | Network with subnet-frontend and subnet-backend |

> The Resource Group and the App Service Plan are **pre-created by the trainer** — Terraform does not manage them.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.9
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli), logged in (`az login`)
- An [HCP Terraform](https://app.terraform.io) account with access to the `alderic-hoarau` organization (`terraform login`)
- **Contributor** role on the target Resource Group
- **Storage Blob Data Owner** and **Storage Queue Data Contributor** roles on the target Resource Group — required because the storage accounts have `shared_access_key_enabled = false`; the `azurerm` provider authenticates to the storage data plane via Azure AD (`storage_use_azuread = true` in [providers.tf](terraform/providers.tf)) instead of account keys

## Local Git hooks

A [`.pre-commit-config.yaml`](.pre-commit-config.yaml) runs `terraform fmt`, `terraform validate` and `tflint` before each commit — the same checks as the `Validate` job in [ci.yml](.github/workflows/ci.yml), so issues are caught locally instead of failing in CI. One-time setup:

```bash
pip install pre-commit   # or: brew install pre-commit
pre-commit install
```

## Local usage

```bash
cd terraform

# 1. Log in to HCP Terraform (one-time per machine, stores a token in ~/.terraform.d/credentials.tfrc.json)
terraform login

# 2. Initialize (state + run history are stored in HCP Terraform, see backend.tf)
terraform init

# 3. Plan / Apply — blocked by default, see below
terraform plan \
  -var="owner=first-last" \
  -var="resource_group_name=rg-first-last"
```

`plan`/`apply`/`destroy` are gated by the required `automation_only` variable ([variables.tf](terraform/variables.tf)): the CI pipeline sets `TF_VAR_automation_only=true` automatically, but running any of these commands locally without it fails with `Error: No value for required variable`. This is intentional — it's a guard rail so infrastructure changes normally only happen through the reviewed GitHub Actions pipeline. `terraform validate` and `terraform fmt` are unaffected and still work locally without it. If you deliberately need to `plan`/`apply`/`destroy` locally, add `-var="automation_only=true"` explicitly.

The HCP Terraform workspace (`azure-infra-alderic-hoarau`) runs in **local execution mode**: `plan`/`apply` still run on your machine (or in CI) using your own Azure credentials — HCP Terraform only stores state and run history, it does not execute Terraform itself.

## CI/CD (GitHub Actions)

### Required secrets

| Secret | Description |
| --- | --- |
| `AZURE_CLIENT_ID` | Client ID of the Service Principal (OIDC) |
| `AZURE_TENANT_ID` | Azure AD Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Subscription ID |
| `AZURE_OWNER` | Learner identifier (`first-last`) |
| `AZURE_RG_NAME` | Resource Group name (`rg-first-last`) |
| `TF_API_TOKEN` | HCP Terraform team token, exposed as `TF_TOKEN_app_terraform_io` for state/run access |
| `INFRACOST_API_KEY` | Infracost API key (cost estimation on PRs) |

### Workflows

| Workflow | Trigger | Actions |
| --- | --- | --- |
| **Terraform CI** (`.github/workflows/ci.yml`) | Push to `main` / PR | fmt, tflint, validate, Checkov, Infracost |
| **Terraform Deploy** (`.github/workflows/terraform.yml`) | Manual (`workflow_dispatch`) | plan / apply / destroy |
| **Terraform Weekly Cleanup** (`.github/workflows/terraform-cleanup.yml`) | Manual (`workflow_dispatch`) — the Friday 18:00 Paris `schedule` trigger is currently disabled (commented out in the workflow) | destroy — tears down all resources before the weekend |

## Structure

```
terraform/
├── main.tf              # Core resources
├── variables.tf         # Input variables
├── outputs.tf            # Exported values
├── providers.tf          # azurerm provider (OIDC + Azure AD storage auth)
├── backend.tf             # HCP Terraform backend (cloud block, local execution mode)
└── .tflint.hcl            # tflint config + azurerm plugin
```

Resources are provisioned via reusable modules published as their own GitHub repos (a private Terraform
module registry, one repo per module) rather than a local `modules/` directory:

| Module | Repo |
| --- | --- |
| App Service | [terraform-azurerm-app-service](https://github.com/alderichoarau/terraform-azurerm-app-service) |
| Storage Account | [terraform-azurerm-storage](https://github.com/alderichoarau/terraform-azurerm-storage) |
| Function App | [terraform-azurerm-function-app](https://github.com/alderichoarau/terraform-azurerm-function-app) |
| Container Instance | [terraform-azurerm-container](https://github.com/alderichoarau/terraform-azurerm-container) |
| Network | [terraform-azurerm-network](https://github.com/alderichoarau/terraform-azurerm-network) |

Each module repo has its own `README.md` (inputs, outputs, resources) auto-generated by
[terraform-docs](https://terraform-docs.io), regenerated on commit via its `terraform_docs` pre-commit hook.

## Contributing

This repository does not accept external contributions. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

All rights reserved. See [LICENSE](LICENSE).
