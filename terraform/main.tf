# ──────────────────────────────────────────────────────────────────────────────
# main.tf — shared locals and data sources
#
# Mirror of azure-infra-cli/bash/provision.sh, managed by Terraform:
#   - storage.tf         — Storage Account + Blob containers (api-logs private / api-config public)
#   - app-service.tf      — Python App Service (shared plan)
#   - function-app.tf     — Python Function App + dedicated storage (shared plan)
#   - static-web-app.tf   — Static Web App
#   - container.tf        — Azure Container Instance (ACI — nginx)
#   - network.tf          — Network: VNet + subnets + NSG
# ──────────────────────────────────────────────────────────────────────────────

locals {
  tags = merge(
    {
      managed_by  = "terraform"
      environment = "tp"
      owner       = var.owner
    },
    var.tags
  )
}

# ── Data sources ──────────────────────────────────────────────────────────────

# Resource Group pre-created by the trainer (never managed by Terraform)
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

# Shared App Service plan (in a separate Resource Group)
data "azurerm_service_plan" "shared" {
  name                = var.shared_plan_name
  resource_group_name = var.shared_rg_name
}
