# azure-infra-terraform

Azure infrastructure provisioned with Terraform — PRF2026 training context.

Terraform mirror of the [azure-infra-cli](https://github.com/hoaraualderic/azure-infra-cli) project (Bash scripts).

## Last analysis

[![Terraform CI](https://github.com/alderichoarau/azure-infra-terraform/actions/workflows/ci.yml/badge.svg)](https://github.com/alderichoarau/azure-infra-terraform/actions/workflows/ci.yml)

## Structure: one directory, one state, per cost-control unit

This repo used to be a single `terraform/` directory / single state. It's
now split into several independently appliable/destroyable directories, so a
learner (or the trainer) never has to create — or pay for — a track they're
not currently using:

| Directory | Who applies it | Depends on | Holds |
| --- | --- | --- | --- |
| [`terraform-core/`](terraform-core/) | Each learner, first | — | VNet + subnets + NSG, shared Storage Account, `ci_app_deploy` identity |
| [`terraform-python/`](terraform-python/) | Each learner | `terraform-core`, `terraform-shared-plan` | Python App Service, Function App, Container Instance, observability (Log Analytics/App Insights/alerts) |
| [`terraform-managed-services/`](terraform-managed-services/) | Each learner | `terraform-core`, `terraform-shared-plan` | Postgres, Redis, Key Vault, Java Web App, Angular Static Web App — TP Java/Angular "services managés" |
| [`terraform-aks-app/`](terraform-aks-app/) | Each learner | `terraform-core`, `terraform-shared-aks` | Container Registry + AcrPull/AcrPush role assignments — TP Java/Angular "AKS" |
| [`terraform-prometheus/`](terraform-prometheus/) | Each learner (optional) | `terraform-core`, `terraform-python` | Managed Prometheus + Grafana + Prometheus VM — most expensive per-learner resources, kept opt-in |
| [`terraform-shared-plan/`](terraform-shared-plan/) | Trainer, once per cohort | — | The App Service Plan every learner's Python/Java apps share |
| [`terraform-shared-aks/`](terraform-shared-aks/) | Trainer, per cohort/session | — | The mutualised AKS cluster(s) every learner's AKS track shares |
| `terraform-legacy-retired/` | Nobody | — | The old monolithic directory, inert (`.tf` → `.tf.retired`), kept only as a "what moved where" map |

Cross-directory values flow through `terraform_remote_state` (`terraform-core`'s
outputs, read by every learner-side directory) or plain `data` source lookups
by predictable name (the shared Plan/cluster, looked up by name rather than
remote state — no state coupling for something this stable). Each directory's
own `README.md` explains its specific dependencies and setup order.

Why `terraform-managed-services` and `terraform-aks-app` stay separate states
even though the AKS track's backend connects to the SAME Postgres/Redis
`terraform-managed-services` creates: the two tracks must be creatable and
destroyable independently, on their own schedule, without one forcing the
other's lifecycle — see `terraform-managed-services/README.md`. Same
reasoning splits `terraform-shared-aks` from `terraform-shared-plan`: the AKS
cluster is this repo's most expensive resource and needs to be torn down
between sessions without dragging the (cheap, continuously-needed) App
Service Plan down with it.

## Deployed resources

| Resource | Generated name | Description |
| --- | --- | --- |
| Storage Account | `st<owner>tf` | Business storage — `api-logs` container (private) and `api-config` container (public) — [terraform-core/storage.tf](terraform-core/storage.tf) |
| App Service | `app-<owner>-tf` | Python application on the shared plan — [terraform-python/app-service.tf](terraform-python/app-service.tf) |
| Function App | `fn-<owner>-tf` | Python Azure Function + dedicated storage — [terraform-python/function-app.tf](terraform-python/function-app.tf) |
| Container Instance | `aci-<owner>-tf` | nginx:1.27-alpine, publicly exposed — [terraform-python/container.tf](terraform-python/container.tf) |
| VNet + subnets + NSG | `vnet-<owner>-tf` | Network with subnet-frontend and subnet-backend — [terraform-core/network.tf](terraform-core/network.tf) |
| Log Analytics + Application Insights (x2) + Availability Tests + alerts | `law-<owner>-tf`, `appi-app/func-<owner>-tf` | Observability stack — see [terraform-python/observability.tf](terraform-python/observability.tf) |
| Azure Monitor Workspace (managed Prometheus) | `amw-<owner>-tf` | Metrics backend fed by the Prometheus VM's `remote_write` — see [terraform-prometheus/main.tf](terraform-prometheus/main.tf) |
| Azure Managed Grafana | `grafana-<owner>-tf` | Unified dashboard: Azure Monitor Logs (KQL) + Azure Monitor Workspace (PromQL) |
| Prometheus VM (self-hosted, dedicated subnet) | `vm-prometheus-<owner>-tf` | Scrapes the App Service's `/metrics` and remote-writes to the Monitor Workspace via managed identity — self-configuring at boot, see [templates/prometheus-cloud-init.sh.tpl](terraform-prometheus/templates/prometheus-cloud-init.sh.tpl). Lives on its own `subnet-prometheus` (10.0.3.0/24), not `subnet-backend` — see gotcha below |
| PostgreSQL Flexible Server | `psql-<owner>-tf` | TP Java/Angular ("services managés"). `postgres_public_access` toggles VNet-integrated/no-public-access vs. public+firewall-rule (needed for the AKS track) — see [terraform-managed-services/database.tf](terraform-managed-services/database.tf) |
| Azure Managed Redis | `redis-<owner>-tf` | TP Java/Angular. Replaces the retired Azure Cache for Redis. Public network access is **enabled** (piste AKS — the shared cluster has no VNet peering into this RG) but a Private Endpoint + private DNS zone (`privatelink.redis.azure.net`) still route App Service's traffic over the private path regardless. `access_keys_authentication_enabled = true` so either track can authenticate (TLS required, `client_protocol` defaults to `Encrypted`) — the access key is pushed to Key Vault (`redis-access-key` secret), never output in the clear — see [terraform-managed-services/redis.tf](terraform-managed-services/redis.tf) |
| Container Registry (Java) | `acr<owner>tf` | TP Java/Angular, piste AKS. Basic SKU, RBAC-only (`admin_enabled = false`) — the shared AKS cluster's kubelet identity gets `AcrPull`, `ci_app_deploy` gets `AcrPush` — see [terraform-aks-app/main.tf](terraform-aks-app/main.tf) |
| Key Vault | `kv-<owner>tf` | TP Java/Angular. Stores the PostgreSQL/Redis connection secrets (RBAC authorization, no public access) — see [terraform-managed-services/keyvault.tf](terraform-managed-services/keyvault.tf) |
| App Service Plan (shared) | `plan-npr-prf2026` | Trainer-provisioned, one plan for the whole cohort — hosts every learner's Python App Service + Function App + Java Web App. See [terraform-shared-plan/main.tf](terraform-shared-plan/main.tf) |
| Web App (Java) | `app-java-<owner>-tf` | TP Java/Angular backend, Java 21, on the shared plan above. Outbound VNet Integration on its own `subnet-java-app` to reach Postgres/Redis/Key Vault; CORS locked to the Angular Static Web App's origin; expects a shared `X-Api-Key` header (`backend-api-key` secret) — see [terraform-managed-services/app-service-java.tf](terraform-managed-services/app-service-java.tf) |
| Static Web App (Angular) | `stapp-angular-<owner>-tf` | TP Java/Angular frontend. Hard-pinned to `westeurope` — Static Web Apps only exist in 5 regions worldwide, independent of subscription — see [terraform-managed-services/static-web-app-java.tf](terraform-managed-services/static-web-app-java.tf) |
| Storage container (Java) | `java-uploads-<owner>` | TP Java/Angular, on the **same** Storage Account as the Python TP's `api-logs`/`api-config` (`terraform-core`'s `module.storage_shared`) rather than a new dedicated account. Access is Azure AD/RBAC-only, scoped to just this container for the Java backend's identity — not network-restricted, since disabling public access account-wide would break the Python TP's public `api-config` container. Used by the backend to export quiz results as JSON blobs (see azure-quiz-backend's `QuizResultExportService`). See the design note in [terraform-managed-services/storage-java.tf](terraform-managed-services/storage-java.tf) |
| AKS cluster(s) (shared) | `aks-<environment>-prf2026` | Trainer-provisioned, mutualised across the cohort. Azure RBAC for Kubernetes, App Routing add-on for a managed ingress controller — see [terraform-shared-aks/main.tf](terraform-shared-aks/main.tf) |

> The Resource Group is **pre-created by the trainer** — Terraform does not manage it. The shared App Service Plan and shared AKS cluster are also trainer-provisioned (`terraform-shared-plan/`, `terraform-shared-aks/`), each in its own state so they can be applied/destroyed on their own schedule.

> **TP Java/Angular status: both tracks done.** "Services managés" (Postgres/Redis/Key Vault/Java Web App/Angular SWA) and "AKS" (ACR + Helm deploy to the shared cluster) are both wired up, sharing the same Postgres/Redis instances. The backend is *not* network-isolated to "reachable only from the frontend" in the strict sense (see the design note below) — that requirement turned out to be incompatible with a plain Angular SPA + Static Web App, so it's enforced at the application layer instead (CORS + shared API key) rather than at the network layer.

<details>
<summary>Piste AKS — what's built (design note)</summary>

**Trainer-side, one-time**: `terraform-shared-aks/` provisions the mutualised AKS cluster(s) (non-prod today, prod on request — `var.environments`) in `rg-shared-prf2026`, Azure RBAC enabled for namespace-scoped access, App Routing add-on for a managed ingress controller. `scripts/bootstrap-aks-namespace.sh` is a second trainer-run step, once per learner: creates their namespace and grants their existing `ci_app_deploy` identity "Azure Kubernetes Service RBAC Admin" scoped to just that namespace (plus "Azure Kubernetes Service Cluster User Role" on the cluster itself, and "RBAC Reader" on `app-routing-system` for ingress-IP discovery). Both steps need rights outside any single learner's Resource Group, so — same trust boundary as pre-creating the RG itself — they can't be self-service.

**Learner-side, self-service** (`terraform-aks-app/main.tf`): a Container Registry + `AcrPull`/`AcrPush` grants to the shared cluster's kubelet identity and to `ci_app_deploy`. `azure-quiz-backend`/`azure-quiz-frontend` each got a `Dockerfile`, a `helm/` chart (Deployment/Service/Ingress, per the cahier des charges), and a `deploy-aks.yml` workflow — build, push to ACR, `az aks get-credentials` + `kubelogin` (Azure RBAC, not the cluster's local-admin kubeconfig), read secrets from Key Vault into a `kubectl`-created Secret, `helm upgrade`. Hostnames are `nip.io` (no delegated DNS zone for this training subscription): `<owner>-backend.<ingress-ip>.nip.io` / `<owner>-frontend.<ingress-ip>.nip.io`.

**Postgres/Redis reachability — shared with the "services managés" track.** `database.tf`'s server can't combine `delegated_subnet_id` (VNet-integrated) with public access — unlike Redis/Storage/Key Vault, there's no single flag to flip. `var.postgres_public_access` (default `true`, `terraform-managed-services`) toggles the whole resource between two mutually exclusive configurations: VNet-integrated/no-public-access (no path in from outside the VNet), or public access + the `AllowAllAzureServicesAndResourcesWithinAzureIps` firewall rule (current default — covers both App Service's outbound VNet Integration traffic and the shared AKS cluster's nodes, since both originate from Azure-internal IP ranges). Same credential/TLS-only trade-off already made for Redis and backend↔frontend CORS.
</details>

<details>
<summary>Why the backend isn't network-restricted to the frontend (design note)</summary>

Static Web App's official "linked backend" proxy (the mechanism that would let the frontend server, rather than the end user's browser, be the sole caller of the API) requires the backend to stay publicly reachable — Microsoft's own docs confirm the SWA proxy runs outside any customer VNet and can't reach a network-restricted origin. And with a plain Angular SPA (no linked backend), the browser calls the API directly anyway, so there's no frontend-side network identity to restrict to in the first place.

Options considered: Azure Front Door with Private Link to the backend (real network isolation, but adds a component, cost, and an unverified risk of hitting another Simplon governance policy); loosening the requirement to an application-layer control (chosen); or swapping the frontend for a Web App that can proxy through its own VNet Integration (works, but no longer a Static Web App as scoped).
</details>

## TP Java/Angular — known gotchas

- **First `apply` on a blank Resource Group fails on `azurerm_linux_web_app.java_app` with
  `Error: Provider produced inconsistent final plan ... site_config[0].cors: block count changed
  from 0 to 1`.** This is a known azurerm provider limitation, not a config mistake: the Web App's
  `cors.allowed_origins` references `azurerm_static_web_app.angular_frontend.default_host_name`, a
  hostname Azure generates randomly and can't be known until that Static Web App is actually
  created. On a first apply, both resources are created in the same run, so the provider can't
  predict at plan time whether the `cors` block will end up populated — it guesses wrong and the
  consistency check between plan and apply fails. By the time the error surfaces, the Static Web
  App (upstream in the dependency chain) has already been created successfully and its hostname is
  in state. **Fix: just run `terraform apply` again** — the hostname is no longer an unknown value
  the second time, so the `cors` block plans correctly. Applies against an already-existing state
  never hit this (the ambiguity only exists on first creation).

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.9
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli), logged in (`az login`)
- An [HCP Terraform](https://app.terraform.io) account with access to the `alderic-hoarau` organization (`terraform login`)
- **Contributor** role on the target Resource Group
- **Storage Blob Data Owner** and **Storage Queue Data Contributor** roles on the target Resource Group — required because the storage account has `shared_access_key_enabled = false`; the `azurerm` provider authenticates to the storage data plane via Azure AD (`storage_use_azuread = true` in [terraform-core/providers.tf](terraform-core/providers.tf)) instead of account keys
- **User Access Administrator** (or equivalent custom role) on the target Resource Group — required by [terraform-prometheus/main.tf](terraform-prometheus/main.tf) for the Grafana → Monitoring Reader role assignment (scoped to the Resource Group). Plain Contributor cannot assign roles.
- **User Access Administrator** (or the narrower **Role Based Access Control Administrator**) at the **subscription** level — required for all three Prometheus VM role assignments (`prometheus_publisher`, `prometheus_dce_reader`, `prometheus_dcr_reader`). `azurerm_monitor_workspace` creates its Data Collection Endpoint/Rule inside a separate, Azure-managed resource group (`MA_<workspace-name>_<region>_managed`), not in the learner's own Resource Group — a role granted only on the learner's RG does not reach it. Without subscription-level rights here, `apply` fails on any of these three `azurerm_role_assignment` resources with a 403 `AuthorizationFailed`, even though the RG-level grant above is correctly in place

## Prometheus VM — known gotchas

Deploying [terraform-prometheus/main.tf](terraform-prometheus/main.tf) surfaced several
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
cd terraform-core   # or terraform-python / terraform-managed-services / terraform-aks-app / ...

# 1. Log in to HCP Terraform (one-time per machine, stores a token in ~/.terraform.d/credentials.tfrc.json)
terraform login

# 2. Initialize (state + run history are stored in HCP Terraform, see backend.tf)
terraform init

# 3. Plan / Apply — blocked by default, see below
terraform plan \
  -var="owner=first-last" \
  -var="resource_group_name=rg-first-last"
```

`terraform-core` must be applied before any of `terraform-python` / `terraform-managed-services` / `terraform-aks-app` — they read its outputs via `terraform_remote_state`.

`plan`/`apply`/`destroy` are gated by the required `automation_only` variable (each directory's `variables.tf`): the CI pipeline sets `TF_VAR_automation_only=true` automatically, but running any of these commands locally without it fails with `Error: No value for required variable`. This is intentional — it's a guard rail so infrastructure changes normally only happen through the reviewed GitHub Actions pipeline. `terraform validate` and `terraform fmt` are unaffected and still work locally without it. If you deliberately need to `plan`/`apply`/`destroy` locally, add `-var="automation_only=true"` explicitly.

Every HCP Terraform workspace in this repo runs in **local execution mode**: `plan`/`apply` still run on your machine (or in CI) using your own Azure credentials — HCP Terraform only stores state and run history, it does not execute Terraform itself. This must be set manually per workspace (Settings > General > Execution Mode) — see any directory's `backend.tf` comment for the symptom if it's missed.

## CI/CD (GitHub Actions)

### Required secrets

| Secret | Description |
| --- | --- |
| `AZURE_CLIENT_ID` | Client ID of the Service Principal (OIDC) |
| `AZURE_TENANT_ID` | Azure AD Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Subscription ID |
| `AZURE_OWNER` | Learner identifier (`first-last`) |
| `AZURE_RG_NAME` | Resource Group name (`rg-first-last`) |
| `AZURE_ALERT_EMAIL` | Email address that receives Azure Monitor alert notifications (`terraform-python`'s `alert_email`) |
| `TRAINER_IP_CIDR` | CIDR allowed for SSH (22) on the Prometheus VM, e.g. `203.0.113.4/32` — never `0.0.0.0/0` |
| `TF_API_TOKEN` | HCP Terraform team token, exposed as `TF_TOKEN_app_terraform_io` for state/run access |
| `GH_PAT_APPS` | Fine-grained PAT scoped to `azure-quiz-backend`/`azure-quiz-frontend`, "Secrets: Read and write" only — used by `deploy-terraform.yml` to auto-sync `AZURE_CLIENT_ID` after every apply that includes `terraform-core` |
| `INFRACOST_API_KEY` | Infracost API key (cost estimation on PRs) |

### Workflows

| Workflow | Trigger | Actions |
| --- | --- | --- |
| **Terraform CI** (`.github/workflows/ci.yml`) | Push to `main` / PR | fmt, tflint, validate (matrix over every live directory), Checkov |
| **Terraform Deploy** (`.github/workflows/deploy-terraform.yml`) | Manual — inputs `directories` (space-separated, e.g. `"terraform-core terraform-python"`) and `action` (plan/apply/destroy) | Runs `action` on each listed directory in turn, in the order given; syncs `AZURE_CLIENT_ID` to the app repos after apply if `terraform-core` was included. Covers every directory — per-student tracks and the two trainer-side shared ones — there is deliberately only this one deploy workflow now. |
| **Bootstrap AKS Namespace** (`.github/workflows/bootstrap-aks-namespace.yml`) | Manual, trainer-only | Creates one learner's namespace on the shared cluster + grants their `ci_app_deploy` identity the roles it needs |
| **Terraform Weekly Cleanup** (`.github/workflows/terraform-cleanup.yml`) | Manual (`workflow_dispatch`) — the Friday 18:00 Paris `schedule` trigger is currently disabled (commented out in the workflow) | Destroys `terraform-aks-app` → `terraform-managed-services` → `terraform-python` → `terraform-core`, in that order, before the weekend. Leaves `terraform-shared-aks`/`terraform-shared-plan`/`terraform-prometheus` untouched. |

To run one directory only, pass just that name in `directories` — e.g. `directories=terraform-python`, `action=apply`. To bootstrap several tracks at once, list them in dependency order — e.g. `directories="terraform-core terraform-python terraform-managed-services"`.

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
