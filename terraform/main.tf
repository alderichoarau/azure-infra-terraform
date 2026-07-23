# ──────────────────────────────────────────────────────────────────────────────
# main.tf — shared locals and data sources
#
# Mirror of azure-infra-cli/bash/provision.sh, managed by Terraform:
#   - storage.tf          — Storage Account + Blob containers (api-logs private / api-config public)
#   - app-service.tf       — Python App Service (shared plan)
#   - app-service-java.tf  — Java Web App on the shared plan (TP Java/Angular — services managés)
#   - function-app.tf      — Python Function App + dedicated storage (shared plan)
#   - static-web-app.tf    — Static Web App
#   - container.tf         — Azure Container Instance (ACI — nginx)
#   - network.tf           — Network: VNet + subnets + NSG
#   - database.tf          — PostgreSQL Flexible Server (TP Java/Angular)
#   - redis.tf             — Azure Managed Redis (TP Java/Angular)
#   - keyvault.tf          — Key Vault + secrets Postgres (TP Java/Angular)
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
