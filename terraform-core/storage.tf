module "storage_shared" {
  # checkov:skip=CKV_TF_1: registry module (app.terraform.io), pinned by semver `version` — commit-hash pinning applies to git sources only
  source  = "app.terraform.io/alderic-hoarau/storage/azurerm"
  version = "~> 0.1"

  # Globally-unique Azure name (max 24 chars, lowercase alphanumeric only) —
  # see local.env_suffix_compact (main.tf) for why prod needs its own.
  # nonprod: "stalderichoarautf" (17 chars, unchanged). prod: 21 chars. Both
  # comfortably under the 24-char limit.
  name                = "st${replace(var.owner, "-", "")}${local.env_suffix_compact}tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  tags                = local.tags
}
