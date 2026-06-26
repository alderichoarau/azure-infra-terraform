# ──────────────────────────────────────────────────────────────────────────────
# main.tf — Azure resources provisioned with Terraform
#
# Mirror of azure-infra-cli/bash/provision.sh, managed by Terraform:
#   - Storage Account + Blob containers (api-logs private / api-config public)
#   - Python App Service (shared plan)
#   - Python Function App + dedicated storage (shared plan)
#   - Static Web App
#   - Azure Container Instance (ACI — nginx)
#   - Network: VNet + subnets + NSG
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

# ── Storage ───────────────────────────────────────────────────────────────────

module "storage" {
  source = "./modules/storage"

  owner               = var.owner
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  tags                = local.tags
}

# ── App Service ───────────────────────────────────────────────────────────────

module "app_service" {
  source = "./modules/app-service"

  owner               = var.owner
  resource_group_name = data.azurerm_resource_group.rg.name
  service_plan_id     = data.azurerm_service_plan.shared.id
  tags                = local.tags
}

# Second App Service — added to validate Infracost cost estimation on PR
resource "azurerm_linux_web_app" "app_secondary" {
  # checkov:skip=CKV_AZURE_13: ressource de test Infracost uniquement
  # checkov:skip=CKV_AZURE_16: ressource de test Infracost uniquement
  # checkov:skip=CKV_AZURE_17: ressource de test Infracost uniquement
  # checkov:skip=CKV_AZURE_18: ressource de test Infracost uniquement
  # checkov:skip=CKV_AZURE_63: ressource de test Infracost uniquement
  # checkov:skip=CKV_AZURE_65: ressource de test Infracost uniquement
  # checkov:skip=CKV_AZURE_66: ressource de test Infracost uniquement
  # checkov:skip=CKV_AZURE_71: ressource de test Infracost uniquement
  # checkov:skip=CKV_AZURE_78: ressource de test Infracost uniquement
  # checkov:skip=CKV_AZURE_88: ressource de test Infracost uniquement
  # checkov:skip=CKV_AZURE_213: ressource de test Infracost uniquement
  # checkov:skip=CKV_AZURE_222: ressource de test Infracost uniquement
  name                = "app-${var.owner}-secondary-tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_service_plan.shared.location
  service_plan_id     = data.azurerm_service_plan.shared.id
  https_only          = true

  site_config {
    minimum_tls_version = "1.2"
    application_stack {
      python_version = "3.11"
    }
  }

  tags = local.tags
}

# ── Function App ──────────────────────────────────────────────────────────────

module "function_app" {
  source = "./modules/function-app"

  owner               = var.owner
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  service_plan_id     = data.azurerm_service_plan.shared.id
  tags                = local.tags
}

# ── Static Web App ────────────────────────────────────────────────────────────

resource "azurerm_static_web_app" "stapp" {
  name                = "stapp-${var.owner}-tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = "westeurope"
  sku_tier            = "Free"
  sku_size            = "Free"
  tags                = local.tags
}

# ── Container Instance ────────────────────────────────────────────────────────

module "container" {
  source = "./modules/container"

  owner               = var.owner
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  tags                = local.tags
}

# ── Network ───────────────────────────────────────────────────────────────────

module "network" {
  source = "./modules/network"

  owner               = var.owner
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  tags                = local.tags
}
