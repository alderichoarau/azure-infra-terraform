# Separate HCP Terraform Cloud workspace from every other directory in this
# repo — deliberately: this Plan is meant to stay up continuously (both the
# Python and Java tracks depend on it for every learner), so its
# apply/destroy lifecycle must never be coupled to anything else, especially
# not to ../terraform-shared-aks/'s cluster (see that directory's main.tf for
# the full reasoning on why the two were split apart).
#
# Create this workspace once in the alderic-hoarau HCP Terraform org before
# first apply (either via the UI, or `terraform login` + `terraform init`
# will offer to create it).
#
# REQUIRED manual step after creating it, before any apply from GitHub
# Actions (.github/workflows/terraform-shared-plan.yml) or the CLI will work:
# in the workspace's Settings > General, set Execution Mode to "Local" (not
# the "Remote" default). Not expressible in this HCL block -- it's a
# workspace-level setting, UI/API only. Same setting every other workspace in
# this repo already has: with Remote execution, `terraform plan/apply`
# actually runs on HCP Terraform Cloud's own workers, which have neither
# GitHub Actions' OIDC token nor a logged-in az CLI -- azure/login@v3's OIDC
# federation only reaches the GitHub-hosted runner itself. Symptom if this is
# missed: `unable to build authorizer ... az: executable file not found in
# $PATH` even though the workflow's own Azure Login step succeeded.
terraform {
  cloud {
    organization = "alderic-hoarau"

    workspaces {
      name = "azure-shared-plan-prf2026"
    }
  }
}
