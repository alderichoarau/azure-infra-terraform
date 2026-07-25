terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # >= 4.60 requis par azurerm_managed_redis (redis.tf) — le service
      # historique Azure Cache for Redis n'accepte plus de nouvelles instances.
      version = "~> 4.60"
    }
    # Génère le mot de passe admin PostgreSQL (database.tf) — évite de le faire
    # transiter en variable/tfvars.
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    # Laisse le temps aux role assignments RBAC du Key Vault de se propager avant
    # d'écrire les secrets (keyvault.tf) — sans ça, l'apply échoue parfois en 403
    # sur le premier azurerm_key_vault_secret, la propagation RBAC n'étant pas
    # instantanée côté Azure AD.
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
