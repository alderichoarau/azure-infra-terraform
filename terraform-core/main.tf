# ──────────────────────────────────────────────────────────────────────────────
# main.tf — foundational, per-student resources shared by every track.
#
#   - network.tf      — VNet + subnets + NSG (module.network)
#   - storage.tf       — Shared Storage Account + Blob containers (module.storage_shared)
#   - ci-app-deploy-identity.tf — User-Assigned Identity used by
#     azure-quiz-backend/frontend's deploy(-aks).yml workflows
#
# Deliberately its own directory/state: ../terraform-python,
# ../terraform-managed-services and ../terraform-aks-app all read these
# outputs via terraform_remote_state instead of duplicating the resources,
# so a learner who only wants the "managed services" track (or only "AKS")
# still gets one VNet and one Storage Account, not one per track.
# ──────────────────────────────────────────────────────────────────────────────

locals {
  tags = merge(
    {
      managed_by  = "terraform"
      environment = var.environment
      owner       = var.owner
    },
    var.tags
  )

  # Only for resources whose Azure name must be GLOBALLY unique (Storage
  # Account, Key Vault, ACR, Postgres Flexible Server, Redis, App Service —
  # anything that becomes part of a public DNS name like
  # *.blob.core.windows.net). nonprod/prod now run in two different Azure
  # subscriptions under the same var.owner (see variables.tf's environment
  # description — it assumed one shared subscription, this repo now also
  # supports a fully separate prod subscription), so a name derived from
  # owner alone collides the moment both environments try to create it — hit
  # live on storage.tf's "stalderichoarautf": StorageAccountAlreadyTaken,
  # even though nonprod and prod are two completely separate subscriptions
  # with fully isolated Terraform state.
  #
  # Empty for nonprod so its already-live resource names are byte-for-byte
  # unchanged (no forced recreation of anything that already exists).
  # RG/subscription-scoped names (VNet, this identity, etc.) don't need this
  # -- they can't collide across subscriptions in the first place.
  env_suffix         = var.environment == "prod" ? "-prod" : ""
  env_suffix_compact = var.environment == "prod" ? "prod" : ""
}

# Resource Group pre-created by the trainer (never managed by Terraform)
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}
