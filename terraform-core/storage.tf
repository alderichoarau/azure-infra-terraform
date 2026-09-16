module "storage_shared" {
  # checkov:skip=CKV_TF_1: registry module (app.terraform.io), pinned by semver `version` — commit-hash pinning applies to git sources only
  source  = "app.terraform.io/alderic-hoarau/storage/azurerm"
  version = "~> 0.1"

  # Globally-unique name (24 char max) — see local.env_suffix_compact (main.tf)
  name                = "st${replace(var.owner, "-", "")}${local.env_suffix_compact}tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  tags                = local.tags
}
