# Separate HCP Terraform Cloud workspace from ../terraform's "azure-infra-alderic-hoarau"
# — deliberately: this module's lifecycle (apply once per cohort, almost never destroyed)
# has nothing to do with a per-student RG's apply/destroy cycles, and mixing the two
# states would mean every student `terraform destroy` risks state-locking or, worse,
# accidentally targeting the shared cluster.
#
# Create this workspace once in the alderic-hoarau HCP Terraform org before first apply
# (either via the UI, or `terraform login` + `terraform init` will offer to create it).
#
# REQUIRED manual step after creating it, before any apply from GitHub Actions
# (.github/workflows/terraform-shared-aks.yml) or the CLI with -var flags will
# work: in the workspace's Settings > General, set Execution Mode to "Local"
# (not the "Remote" default). Not expressible in this HCL block -- it's a
# workspace-level setting, UI/API only. Same setting ../terraform's
# "azure-infra-alderic-hoarau" workspace already has, for the same reason:
# with Remote execution, `terraform plan/apply` actually runs on HCP Terraform
# Cloud's own workers, which have neither GitHub Actions' OIDC token nor a
# logged-in az CLI -- azure/login@v3's OIDC federation only reaches the
# GitHub-hosted runner itself. Symptom if this is missed: `unable to build
# authorizer ... az: executable file not found in $PATH` even though the
# workflow's own Azure Login step succeeded.
terraform {
  cloud {
    organization = "alderic-hoarau"

    workspaces {
      name = "azure-shared-aks-prf2026"
    }
  }
}
