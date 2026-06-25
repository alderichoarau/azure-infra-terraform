# Python Function App — dedicated storage + shared plan
# Mirror of step [3] in provision.sh

# Storage dedicated to the Function App (required, separate from business storage)
resource "azurerm_storage_account" "fn_storage" {
  name                     = "stfn${replace(var.owner, "-", "")}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  tags = merge(var.tags, { purpose = "function-storage" })
}

resource "azurerm_linux_function_app" "fn" {
  name                       = "fn-${var.owner}-tf"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  service_plan_id            = var.service_plan_id
  storage_account_name       = azurerm_storage_account.fn_storage.name
  storage_account_access_key = azurerm_storage_account.fn_storage.primary_access_key

  site_config {
    application_stack {
      python_version = "3.11"
    }
  }

  tags = var.tags
}
