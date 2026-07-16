module "container" {
  # checkov:skip=CKV_TF_1: registry module (app.terraform.io), pinned by semver `version` — commit-hash pinning applies to git sources only
  source  = "app.terraform.io/alderic-hoarau/container/azurerm"
  version = "~> 0.1"

  name                = "aci-${var.owner}-tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location

  environment_variables = {
    OWNER       = var.owner
    ENVIRONMENT = "tp"
  }

  tags = local.tags
}
