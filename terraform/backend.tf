# Remote state stored in HCP Terraform (execution-mode = local:
# plan/apply still run on this machine / in CI, only state + run history live in HCP Terraform)
terraform {
  cloud {
    organization = "alderic-hoarau"

    workspaces {
      name = "azure-infra-alderic-hoarau"
    }
  }
}
