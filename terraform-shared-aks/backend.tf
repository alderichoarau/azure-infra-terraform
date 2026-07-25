# Separate HCP Terraform Cloud workspace from ../terraform's "azure-infra-alderic-hoarau"
# — deliberately: this module's lifecycle (apply once per cohort, almost never destroyed)
# has nothing to do with a per-student RG's apply/destroy cycles, and mixing the two
# states would mean every student `terraform destroy` risks state-locking or, worse,
# accidentally targeting the shared cluster.
#
# Create this workspace once in the alderic-hoarau HCP Terraform org before first apply
# (either via the UI, or `terraform login` + `terraform init` will offer to create it).
terraform {
  cloud {
    organization = "alderic-hoarau"

    workspaces {
      name = "azure-shared-aks-prf2026"
    }
  }
}
