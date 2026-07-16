module "app_service" {
  # checkov:skip=CKV_TF_1: registry module (app.terraform.io), pinned by semver `version` — commit-hash pinning applies to git sources only
  source  = "app.terraform.io/alderic-hoarau/app-service/azurerm"
  version = "~> 0.1"

  name                = "app-${var.owner}-tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  service_plan_id     = data.azurerm_service_plan.shared.id
  app_settings        = { ENVIRONMENT = "tp" }
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
