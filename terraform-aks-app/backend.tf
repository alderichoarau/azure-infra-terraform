# This track's own state — separate from ../terraform-core (network/storage/
# identity, applied once) and from ../terraform-python / ../terraform-managed-services
# (the other two tracks), so the "AKS" track (ACR + role assignments to the
# shared cluster) can be applied or destroyed on its own for cost control,
# independent of whichever other tracks a student has or hasn't enabled.
#
# REQUIRED manual step after creating this workspace: Execution Mode "Local"
# — see ../terraform-shared-aks/backend.tf's comment for why.
terraform {
  cloud {
    organization = "alderic-hoarau"

    workspaces {
      name = "azure-aks-app-alderic-hoarau"
    }
  }
}
