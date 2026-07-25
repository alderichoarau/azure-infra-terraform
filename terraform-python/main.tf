# ──────────────────────────────────────────────────────────────────────────────
# main.tf — TP observabilité Python: App Service + Function App + Container
# Instance + Log Analytics/App Insights/alerts.
#
#   - app-service.tf   — Python App Service (shared plan)
#   - function-app.tf  — Python Function App + dedicated storage (shared plan)
#   - container.tf     — Azure Container Instance (ACI — nginx)
#   - observability.tf — Log Analytics + App Insights + diagnostic settings +
#                         availability tests + alerts, wired to the three above
#
# Mirror of azure-infra-cli/bash/provision.sh, managed by Terraform.
#
# Reads ../terraform-core's network/storage outputs via
# data.terraform_remote_state.core rather than duplicating those resources —
# see terraform-core/README.md for why the split.
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

data "terraform_remote_state" "core" {
  backend = "remote"

  config = {
    organization = "alderic-hoarau"
    workspaces = {
      name = var.core_workspace_name
    }
  }
}
