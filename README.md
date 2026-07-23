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
| Function App | `fn-<owner>-tf` | Python Azure Function + dedicated storage |
| Container Instance | `aci-<owner>-tf` | nginx:1.27-alpine, publicly exposed |
| VNet + subnets + NSG | `vnet-<owner>-tf` | Network with subnet-frontend and subnet-backend |
| Log Analytics + Application Insights (x2) + Availability Tests + alerts | `law-<owner>-tf`, `appi-app/func-<owner>-tf` | Observability stack — see [observability.tf](terraform/observability.tf), corrigé for the `tp-observability` TP |
| Azure Monitor Workspace (managed Prometheus) | `amw-<owner>-tf` | Metrics backend fed by the Prometheus VM's `remote_write` — see [observability-prometheus.tf](terraform/observability-prometheus.tf) |
| Azure Managed Grafana | `grafana-<owner>-tf` | Unified dashboard: Azure Monitor Logs (KQL) + Azure Monitor Workspace (PromQL) |
| Prometheus VM (self-hosted, dedicated subnet) | `vm-prometheus-<owner>-tf` | Scrapes the App Service's `/metrics` and remote-writes to the Monitor Workspace via managed identity — self-configuring at boot, see [templates/prometheus-cloud-init.sh.tpl](terraform/templates/prometheus-cloud-init.sh.tpl). Lives on its own `subnet-prometheus` (10.0.3.0/24), not `subnet-backend` — see gotcha below |
| PostgreSQL Flexible Server | `psql-<owner>-tf` | TP Java/Angular ("services managés"). Burstable tier, VNet-integrated on its own delegated `subnet-data` (10.0.4.0/24), no public access — see [database.tf](terraform/database.tf) |
| Azure Managed Redis | `redis-<owner>-tf` | TP Java/Angular. Replaces the retired Azure Cache for Redis. No public access, reachable only via its Private Endpoint on `subnet-backend` — see [redis.tf](terraform/redis.tf) |
| Key Vault | `kv-<owner>tf` | TP Java/Angular. Stores the PostgreSQL connection secrets (RBAC authorization, no public access) — see [keyvault.tf](terraform/keyvault.tf) |
| App Service Plan (Java) | `plan-java-<owner>-tf` | TP Java/Angular — S3, in the learner's own Resource Group (not shared with the Python App Service's plan above). Created in the same `terraform apply` as the Web App below; Terraform sequences plan-then-app automatically via the resource dependency, no separate step — see [app-service-java.tf](terraform/app-service-java.tf) |
| Web App (Java) | `app-java-<owner>-tf` | TP Java/Angular backend, Java 21, on the plan above. Outbound VNet Integration on `subnet-backend` to reach Postgres/Redis/Key Vault; CORS locked to the Angular Static Web App's origin; expects a shared `X-Api-Key` header (`backend-api-key` secret) — see [app-service-java.tf](terraform/app-service-java.tf) |
| Static Web App (Angular) | `stapp-angular-<owner>-tf` | TP Java/Angular frontend. Hard-pinned to `westeurope` — Static Web Apps only exist in 5 regions worldwide, independent of subscription — see [static-web-app-java.tf](terraform/static-web-app-java.tf) |
| Storage container (Java) | `java-uploads-<owner>` | TP Java/Angular, on the **same** Storage Account as the Python TP's `api-logs`/`api-config` (module.storage) rather than a new dedicated account. Access is Azure AD/RBAC-only, scoped to just this container for the Java backend's identity — not network-restricted, since disabling public access account-wide would break the Python TP's public `api-config` container. See the design note in [storage-java.tf](terraform/storage-java.tf) |

> The Resource Group and the (Python) App Service Plan are **pre-created by the trainer** — Terraform does not manage them. The Java TP's own App Service Plan, on the other hand, **is** Terraform-managed, in the learner's own Resource Group alongside everything else (see [app-service-java.tf](terraform/app-service-java.tf)).

> **TP Java/Angular status: "services managés" track done, AKS track not started.** Backend, frontend, database, cache and secrets store are wired up. The backend is *not* network-isolated to "reachable only from the frontend" in the strict sense (see the design note below) — that requirement turned out to be incompatible with a plain Angular SPA + Static Web App, so it's enforced at the application layer instead (CORS + shared API key) rather than at the network layer.

<details>
<summary>Why the backend isn't network-restricted to the frontend (design note)</summary>

Static Web App's official "linked backend" proxy (the mechanism that would let the frontend server, rather than the end user's browser, be the sole caller of the API) requires the backend to stay publicly reachable — Microsoft's own docs confirm the SWA proxy runs outside any customer VNet and can't reach a network-restricted origin. And with a plain Angular SPA (no linked backend), the browser calls the API directly anyway, so there's no frontend-side network identity to restrict to in the first place.

Options considered: Azure Front Door with Private Link to the backend (real network isolation, but adds a component, cost, and an unverified risk of hitting another Simplon governance policy); loosening the requirement to an application-layer control (chosen); or swapping the frontend for a Web App that can proxy through its own VNet Integration (works, but no longer a Static Web App as scoped).
</details>

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.9
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli), logged in (`az login`)
- An [HCP Terraform](https://app.terraform.io) account with access to the `alderic-hoarau` organization (`terraform login`)
- **Contributor** role on the target Resource Group
- **Storage Blob Data Owner** and **Storage Queue Data Contributor** roles on the target Resource Group — required because the storage accounts have `shared_access_key_enabled = false`; the `azurerm` provider authenticates to the storage data plane via Azure AD (`storage_use_azuread = true` in [providers.tf](terraform/providers.tf)) instead of account keys
- **User Access Administrator** (or equivalent custom role) on the target Resource Group — required by [observability-prometheus.tf](terraform/observability-prometheus.tf) for the Grafana → Monitoring Reader role assignment (scoped to the Resource Group). Plain Contributor cannot assign roles.
- **User Access Administrator** (or the narrower **Role Based Access Control Administrator**) at the **subscription** level — required for all three Prometheus VM role assignments (`prometheus_publisher`, `prometheus_dce_reader`, `prometheus_dcr_reader`). `azurerm_monitor_workspace` creates its Data Collection Endpoint/Rule inside a separate, Azure-managed resource group (`MA_<workspace-name>_<region>_managed`), not in the learner's own Resource Group — a role granted only on the learner's RG does not reach it. Without subscription-level rights here, `apply` fails on any of these three `azurerm_role_assignment` resources with a 403 `AuthorizationFailed`, even though the RG-level grant above is correctly in place

## Prometheus VM — known gotchas

Deploying [observability-prometheus.tf](terraform/observability-prometheus.tf) surfaced several
non-obvious issues, worth knowing before touching this file again:

- **Dedicated subnet, not `subnet-backend`.** The Prometheus VM's NIC lives on its own
  `subnet-prometheus` (10.0.3.0/24), carrying only its own NSG (`nsg-prometheus-<owner>-tf`).
  It used to sit on the shared `subnet-backend`, with extra `azurerm_network_security_rule`
  resources bolted onto the module's `nsg-backend`. That NSG already declares its full rule set
  via inline `security_rule` blocks — mixing inline blocks and standalone
  `azurerm_network_security_rule` on the *same* NSG is an explicit AzureRM anti-pattern: both
  fight over the rule list on every apply, and one of the two added rules randomly went missing
  each time. Moving to an isolated subnet+NSG this repo fully owns removed the conflict entirely.
- **SSH access needs your real IPv4, not IPv6.** `TRAINER_IP_CIDR` must match the client's actual
  outbound IPv4 address (`curl -4 -s https://ifconfig.me`) — the VM's public IP is IPv4-only
  (default `azurerm_public_ip`, no `ip_version = "IPv6"`), so an IPv6-sourced SSH connection times
  out no matter what the NSG says, and looks identical to a real NSG misconfiguration.
- **`Monitoring Metrics Publisher` is write-only.** It lets the VM's managed identity
  `remote_write` metrics but grants no read access on the DCE/DCR resources themselves. The
  cloud-init script's own `az monitor data-collection endpoint/rule show` calls (to resolve the
  ingestion URL and immutableId) fail with `AuthorizationFailed` using that same identity unless
  it also holds `Monitoring Reader` scoped to both resource IDs — see
  `prometheus_dce_reader`/`prometheus_dcr_reader` in the Terraform.
- **Azure CLI command syntax:** it's `az monitor data-collection endpoint show` / `data-collection
  rule show` (two words), not `data-collection-endpoint` / `data-collection-rule` (hyphenated) —
  the latter is the old `monitor-control-service` extension syntax and fails with "not recognized
  by the system" on current `az cli`.
- **VM size:** `Standard_B1s` and every `Standard_B*_v2` size are `NotAvailableForSubscription` in
  `francecentral` on this training subscription (a subscription-tier restriction, not regional
  capacity) — default is `Standard_D2s_v3` (`var.prometheus_vm_size`), broadly available.
- **`grafana_major_version` drifts fast.** Valid values shifted from `["11","12"]` to `["12","13"]`
  within days of each other on this repo. If `apply` rejects the current value, trust the error
  message's list of valid versions over this README or any external doc.
- **Prometheus binary version matters for the auth method.** System-assigned managed identity
  (what this VM uses — `managed_identity.client_id = ""` in `prometheus.yml`) requires Prometheus
  **3.50+** per Microsoft's own docs. An earlier iteration of the cloud-init template pinned
  2.53.0 (which only supports *user-assigned* managed identity) — the service crash-looped with
  `must provide an Azure Managed Identity client_id in the Azure AD config`. Now pinned to 3.12.0.

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
| `AZURE_ALERT_EMAIL` | Email address that receives Azure Monitor alert notifications (was already required by `alert_email` in `variables.tf`, missing from this table until now) |
| `TRAINER_IP_CIDR` | CIDR allowed for SSH (22) on the Prometheus VM, e.g. `203.0.113.4/32` — never `0.0.0.0/0` |
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
