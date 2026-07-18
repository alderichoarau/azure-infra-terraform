terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    # Génère la paire de clés SSH de la VM Prometheus (observability-prometheus.tf) —
    # évite un file("~/.ssh/id_rsa.pub") qui casserait en CI (pas de clé locale sur le runner).
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  # Authentication via OIDC — no client secret
  # ARM_CLIENT_ID, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID injected by GitHub Actions
  use_oidc = true

  # Storage accounts have shared_access_key_enabled = false (security hardening),
  # so the provider must use Azure AD instead of account keys for data-plane calls
  # (e.g. reading queue properties right after creating the storage account).
  storage_use_azuread = true

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}
