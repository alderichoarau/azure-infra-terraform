terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.60"
    }
  }
}

provider "azurerm" {
  # Same auth model as ../terraform (student workspace): OIDC, no client secret.
  # Applied by the trainer's own identity though — see README.md in this
  # directory for who's expected to run this and how often (rare: once per
  # cohort / once per new environment, not per-student).
  use_oidc = true

  features {
    resource_group {
      # This module never creates or destroys the shared RG itself (see main.tf
      # — it's a data source, "pre-existing, owned outside this module"), only
      # matters if a future resource here ever gets deleted while other shared
      # resources (the App Service plan, etc.) still live in the same RG.
      prevent_deletion_if_contains_resources = true
    }
  }
}
