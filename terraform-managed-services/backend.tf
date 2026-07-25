# This track's own state — separate from ../terraform-core (network/storage/
# identity, applied once) and from ../terraform-python / ../terraform-aks-app
# (the other two tracks), so the "services managés" track (Postgres, Redis,
# Key Vault, Java Web App, Angular Static Web App) can be applied or
# destroyed on its own for cost control. In particular: this must be able to
# come up or go down WITHOUT touching ../terraform-aks-app, even though both
# tracks share the same Postgres/Redis instances created here — see
# database.tf's postgres_public_access note and this directory's README.
#
# REQUIRED manual step after creating this workspace: Execution Mode "Local"
# — see ../terraform-shared-aks/backend.tf's comment for why.
terraform {
  cloud {
    organization = "alderic-hoarau"

    workspaces {
      name = "azure-managed-services-alderic-hoarau"
    }
  }
}
