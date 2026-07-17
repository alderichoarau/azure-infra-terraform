module "function_app" {
  # checkov:skip=CKV_TF_1: registry module (app.terraform.io), pinned by semver `version` — commit-hash pinning applies to git sources only
  source  = "app.terraform.io/alderic-hoarau/function-app/azurerm"
  version = "~> 0.1"

  name                 = "fn-${var.owner}-tf"
  storage_account_name = "stfn${replace(var.owner, "-", "")}"
  resource_group_name  = data.azurerm_resource_group.rg.name
  location             = var.location
  service_plan_id      = data.azurerm_service_plan.shared.id
  app_settings = {
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.func.connection_string
  }
  tags = local.tags
}
