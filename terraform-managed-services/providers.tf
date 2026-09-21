terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # >= 4.60 required by azurerm_managed_redis (redis.tf) — the legacy
      # Azure Cache for Redis service no longer accepts new instances.
      version = "~> 5.6"
    }
    # Generates the Postgres admin password (database.tf) — avoids passing it
    # through a variable/tfvars.
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    # Gives Key Vault's RBAC role assignments time to propagate before writing
    # secrets (keyvault.tf) — without this, apply sometimes fails 403 on the
    # first azurerm_key_vault_secret since Azure AD's RBAC propagation isn't
    # instant.
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
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
