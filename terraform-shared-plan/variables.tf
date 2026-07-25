variable "shared_rg_name" {
  description = "Resource Group pre-created by the trainer, shared across the whole cohort — also holds ../terraform-shared-aks/'s AKS cluster(s), own state (see that directory's main.tf for why they're split)."
  type        = string
  default     = "rg-shared-prf2026"
}

variable "location" {
  type    = string
  default = "francecentral"
}

variable "plan_name" {
  description = "Name of the shared App Service Plan. Every per-student directory that reads this plan (../terraform-python, ../terraform-managed-services) defaults its own shared_plan_name var to this same value — keep both in sync if you ever rename it."
  type        = string
  default     = "plan-npr-prf2026"
}

variable "plan_sku" {
  description = "SKU for the shared App Service Plan. S3: sized to comfortably host every learner's Python App Service + Function App + Java Web App on one pool of compute (all three are Linux app stacks — an App Service Plan is just capacity, Azure isolates each app within it regardless of runtime)."
  type        = string
  default     = "S3"
}
