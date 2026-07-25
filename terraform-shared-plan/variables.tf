variable "shared_rg_name" {
  description = "Resource Group pre-created by the trainer, shared across the whole cohort — also holds ../terraform-shared-aks/'s AKS cluster(s), own state (see that directory's main.tf for why they're split). No default on purpose — comes from the AZURE_SHARED_RG_NAME GitHub secret (TF_VAR_shared_rg_name, deploy-terraform.yml) or an explicit -var locally, so this naming convention isn't hardcoded in the repo."
  type        = string
}

variable "location" {
  type    = string
  default = "francecentral"
}

variable "plan_name" {
  description = "Name of the shared App Service Plan. Every per-student directory that reads this plan (../terraform-python, ../terraform-managed-services) sets its own shared_plan_name var to this same value — keep both in sync if you ever rename it. No default on purpose — comes from the AZURE_SHARED_PLAN_NAME GitHub secret (TF_VAR_plan_name) or an explicit -var locally."
  type        = string
}

variable "plan_sku" {
  description = "SKU for the shared App Service Plan. S3: sized to comfortably host every learner's Python App Service + Function App + Java Web App on one pool of compute (all three are Linux app stacks — an App Service Plan is just capacity, Azure isolates each app within it regardless of runtime)."
  type        = string
  default     = "S3"
}
