# Remote state stored in Azure Blob Storage
# Backend config values are injected at runtime via -backend-config in CI
# or via a backend.hcl file locally (never commit secrets here)
terraform {
  backend "azurerm" {
    # resource_group_name  → injected via -backend-config or TF_BACKEND_RG secret
    # storage_account_name → injected via -backend-config or TF_BACKEND_SA secret
    # container_name       = "tfstate"
    # key                  = "<owner>.terraform.tfstate"
  }
}
