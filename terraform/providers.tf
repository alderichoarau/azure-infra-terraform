terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  # Authentication via OIDC — no client secret
  # ARM_CLIENT_ID, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID injected by GitHub Actions
  use_oidc = true

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}
