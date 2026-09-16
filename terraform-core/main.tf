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

  # Resource-name suffix: nonprod keeps its exact current names (live cohort
  # resources, never renamed). prod adds app name + environment to every
  # resource. resource_suffix_compact drops owner for the 24-char-limited
  # resources (Key Vault, Storage) — prod is single-tenant, doesn't need it.
  resource_suffix         = var.environment == "prod" ? "${var.owner}-${var.app_name}-prod" : var.owner
  resource_suffix_compact = var.environment == "prod" ? "${var.app_name}prod" : replace(var.owner, "-", "")
}

# Resource Group pre-created by the trainer (never managed by Terraform)
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}
