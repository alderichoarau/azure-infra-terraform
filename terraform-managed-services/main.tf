# ──────────────────────────────────────────────────────────────────────────────
# main.tf — TP Java/Angular, piste "services managés".
#
#   - database.tf          — PostgreSQL Flexible Server
#   - redis.tf              — Azure Managed Redis
#   - keyvault.tf            — Key Vault + secrets Postgres/Redis/API key
#   - app-service-java.tf    — Java backend Web App on the shared plan
#   - static-web-app-java.tf — Angular frontend (Static Web App)
#   - storage-java.tf        — Storage container on the shared Storage Account
#
# Reads ../terraform-core's network/storage/ci_app_deploy outputs via
# data.terraform_remote_state.core rather than duplicating those resources —
# see terraform-core/README.md for why the split. Postgres and Redis created
# here are also the ones the AKS track's backend deployment connects to
# (deploy-aks.yml in azure-quiz-backend) — this directory must exist and be
# applied for either track's backend to have a database, but the two tracks'
# own Terraform states stay fully independent (see backend.tf's comment).
# ──────────────────────────────────────────────────────────────────────────────

locals {
  tags = merge(
    {
      managed_by  = "terraform"
      environment = var.environment
      owner       = var.owner
    },
    var.tags
  )
}

# Resource Group pre-created by the trainer (never managed by Terraform)
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

# Shared App Service plan (../terraform-shared-plan, separate Resource Group)
data "azurerm_service_plan" "shared" {
  name                = var.shared_plan_name
  resource_group_name = var.shared_rg_name
}

data "azurerm_client_config" "current" {}

data "terraform_remote_state" "core" {
  backend = "remote"

  config = {
    organization = "alderic-hoarau"
    workspaces = {
      name = var.core_workspace_name
    }
  }
}
