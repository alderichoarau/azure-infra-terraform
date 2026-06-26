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

resource "azurerm_storage_account" "sa" {
  name                     = "st${replace(var.owner, "-", "")}tf"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  min_tls_version          = "TLS1_2"

  # checkov:skip=CKV_AZURE_59: api-config container is intentionally public (static config blobs)
  allow_nested_items_to_be_public = true

  tags = var.tags
}

# Private container — API logs
resource "azurerm_storage_container" "api_logs" {
  name                  = "api-logs"
  storage_account_id    = azurerm_storage_account.sa.id
  container_access_type = "private"
}

# Public container — API configuration
resource "azurerm_storage_container" "api_config" {
  name                  = "api-config"
  storage_account_id    = azurerm_storage_account.sa.id
  container_access_type = "blob"
}
