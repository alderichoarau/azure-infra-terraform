# Business Storage Account + Blob containers (private/public)
# Mirror of steps [1] and [6] in provision.sh

terraform {
  required_version = ">= 1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# checkov:skip=CKV2_AZURE_1: CMK nécessite Azure Key Vault, hors périmètre TP
# checkov:skip=CKV_AZURE_33: logs queue storage non requis en contexte TP
# checkov:skip=CKV_AZURE_206: réplication GRS trop coûteuse pour TP (LRS suffisant)
# checkov:skip=CKV2_AZURE_33: private endpoint nécessite VNet integration, hors périmètre TP
# checkov:skip=CKV2_AZURE_41: politique expiration SAS hors périmètre TP
resource "azurerm_storage_account" "sa" {
  name                      = "st${replace(var.owner, "-", "")}tf"
  resource_group_name       = var.resource_group_name
  location                  = var.location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  account_kind              = "StorageV2"
  min_tls_version           = "TLS1_2"
  shared_access_key_enabled = false

  # checkov:skip=CKV_AZURE_59: api-config container is intentionally public (static config blobs)
  # checkov:skip=CKV_AZURE_190: accès public blob intentionnel pour api-config
  # checkov:skip=CKV2_AZURE_47: accès anonyme intentionnel pour api-config
  allow_nested_items_to_be_public = true

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

# checkov:skip=CKV2_AZURE_21: logs lecture blob non requis en contexte TP
# Private container — API logs
resource "azurerm_storage_container" "api_logs" {
  name                  = "api-logs"
  storage_account_id    = azurerm_storage_account.sa.id
  container_access_type = "private"
}

# checkov:skip=CKV_AZURE_34: conteneur public intentionnel — blobs de config statique
# checkov:skip=CKV2_AZURE_21: logs lecture blob non requis en contexte TP
# Public container — API configuration
resource "azurerm_storage_container" "api_config" {
  name                  = "api-config"
  storage_account_id    = azurerm_storage_account.sa.id
  container_access_type = "blob"
}
