# Python Function App — dedicated storage + shared plan
# Mirror of step [3] in provision.sh

terraform {
  required_version = ">= 1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Storage dedicated to the Function App (required, separate from business storage)
resource "azurerm_storage_account" "fn_storage" {
  # checkov:skip=CKV_AZURE_59: accès public désactivé via allow_nested_items_to_be_public (azurerm 4.x)
  # checkov:skip=CKV2_AZURE_1: CMK nécessite Azure Key Vault, hors périmètre TP
  # checkov:skip=CKV_AZURE_206: réplication GRS trop coûteuse pour TP (LRS suffisant)
  # checkov:skip=CKV_AZURE_33: logs queue storage non requis en contexte TP
  # checkov:skip=CKV2_AZURE_33: private endpoint nécessite VNet integration, hors périmètre TP
  # checkov:skip=CKV2_AZURE_41: politique expiration SAS hors périmètre TP
  # checkov:skip=CKV2_AZURE_21: logs lecture blob non requis en contexte TP
  name                            = "stfn${replace(var.owner, "-", "")}"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  tags = merge(var.tags, { purpose = "function-storage" })
}

resource "azurerm_linux_function_app" "fn" {
  # checkov:skip=CKV_AZURE_221: accès réseau public requis pour le TP
  name                          = "fn-${var.owner}-tf"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  service_plan_id               = var.service_plan_id
  storage_account_name          = azurerm_storage_account.fn_storage.name
  storage_uses_managed_identity = true
  https_only                    = true

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = "3.11"
    }
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "fn_storage_blob" {
  scope                = azurerm_storage_account.fn_storage.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_linux_function_app.fn.identity[0].principal_id
}
