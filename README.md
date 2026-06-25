# azure-infra-terraform

Infrastructure Azure provisionnée avec Terraform — contexte formation PRF2026.

Miroir Terraform du projet [azure-infra-cli](https://github.com/hoaraualderic/azure-infra-cli) (scripts Bash).

## Ressources déployées

| Ressource | Nom généré | Description |
|-----------|-----------|-------------|
| Storage Account | `st<owner>tf` | Stockage métier — containers `api-logs` (privé) et `api-config` (public) |
| App Service | `app-<owner>-tf` | Application Python 3.11 sur plan partagé |
| Function App | `fn-<owner>-tf` | Azure Function Python 3.11 + storage dédié |
| Static Web App | `stapp-<owner>-tf` | Site statique (Free tier) |
| Container Instance | `aci-<owner>-tf` | nginx:1.27-alpine exposé en public |
| VNet + subnets + NSG | `vnet-<owner>-tf` | Réseau avec subnet-frontend et subnet-backend |

> Le Resource Group et l'App Service Plan sont **pré-créés par le formateur** — Terraform ne les gère pas.

## Prérequis

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.9
- [Azure CLI](https://learn.microsoft.com/fr-fr/cli/azure/install-azure-cli) connecté (`az login`)
- Rôle **Storage Blob Data Contributor** sur le storage account backend
- Rôle **Contributor** sur le Resource Group cible

## Utilisation locale

```bash
cd terraform

# 1. Initialiser avec le backend Azure
terraform init -backend-config=backend.hcl

# 2. Planifier
terraform plan \
  -var="owner=prenom-nom" \
  -var="resource_group_name=rg-prenom-nom"

# 3. Appliquer
terraform apply \
  -var="owner=prenom-nom" \
  -var="resource_group_name=rg-prenom-nom"
```

### Fichier backend.hcl (local uniquement, jamais commité)

```hcl
resource_group_name  = "rg-formateur-prf2026"
storage_account_name = "<storage-account-backend>"
container_name       = "tfstate"
key                  = "prenom-nom.terraform.tfstate"
use_azuread_auth     = true
```

## CI/CD (GitHub Actions)

### Secrets requis

| Secret | Description |
|--------|-------------|
| `AZURE_CLIENT_ID` | Client ID du Service Principal (OIDC) |
| `AZURE_TENANT_ID` | Tenant ID Azure AD |
| `AZURE_SUBSCRIPTION_ID` | ID de la subscription |
| `AZURE_OWNER` | Identifiant apprenant (`prenom-nom`) |
| `AZURE_RG_NAME` | Nom du Resource Group (`rg-prenom-nom`) |
| `TF_BACKEND_RG` | Resource Group du backend Terraform |
| `TF_BACKEND_SA` | Nom du Storage Account backend |
| `INFRACOST_API_KEY` | Clé API Infracost (estimation de coût sur PR) |

### Workflows

| Workflow | Déclencheur | Actions |
|----------|------------|---------|
| **Terraform CI** (`.github/workflows/ci.yml`) | Push `main` / PR | fmt, tflint, validate, Checkov, Infracost |
| **Terraform Deploy** (`.github/workflows/terraform.yml`) | Manuel (`workflow_dispatch`) | plan / apply / destroy |

## Structure

```
terraform/
├── main.tf              # Ressources principales
├── variables.tf         # Variables d'entrée
├── outputs.tf           # Valeurs exportées
├── providers.tf         # Provider azurerm (OIDC)
├── backend.tf           # Backend azurerm (config injectée)
├── .tflint.hcl          # Config tflint + plugin azurerm
└── modules/
    ├── app-service/     # azurerm_linux_web_app
    ├── container/       # azurerm_container_group
    ├── function-app/    # azurerm_linux_function_app
    ├── network/         # VNet + subnets + NSG
    └── storage/         # Storage Account + containers
```
