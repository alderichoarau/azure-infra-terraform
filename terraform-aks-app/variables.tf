variable "owner" {
  description = "Learner identifier — must match ../terraform-core's var.owner (same RG, same resource-naming convention)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]+[a-z0-9]$", var.owner))
    error_message = "owner must be lowercase, letters, digits and hyphens only."
  }
}

variable "resource_group_name" {
  description = "Name of the Resource Group pre-created by the trainer — same one ../terraform-core uses."
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "francecentral"
}

variable "environment" {
  description = "Environment this deployment belongs to — must match one of ../terraform-shared-aks's var.environments, since it's used to build the shared cluster's name below."
  type        = string
  default     = "nonprod"

  validation {
    condition     = contains(["nonprod", "prod"], var.environment)
    error_message = "environment must be either \"nonprod\" or \"prod\"."
  }
}

variable "tags" {
  description = "Additional tags to merge with default tags"
  type        = map(string)
  default     = {}
}

variable "shared_rg_name" {
  description = "Resource Group containing the shared AKS cluster (../terraform-shared-aks)"
  type        = string
  default     = "rg-shared-prf2026"
}

variable "cohort" {
  description = "Cohort/promo identifier, must match ../terraform-shared-aks's var.cohort — used to build the shared cluster's name (aks-<environment>-<cohort>) since it lives outside this apply's own Resource Group."
  type        = string
  default     = "prf2026"
}

variable "core_workspace_name" {
  description = "HCP Terraform Cloud workspace name of ../terraform-core, read via terraform_remote_state for the ci_app_deploy identity that needs AcrPush on this track's ACR."
  type        = string
  default     = "azure-core-alderic-hoarau"
}

# tflint-ignore: terraform_unused_declarations # only referenced in its own validation block below, never consumed by a resource
variable "automation_only" {
  description = "Guard against accidental local apply/destroy — set to true only by the CI pipeline (TF_VAR_automation_only)."
  type        = bool

  validation {
    condition     = var.automation_only == true
    error_message = "plan/apply/destroy must run through the GitHub Actions pipeline. If you really mean to run this locally, pass -var=\"automation_only=true\" explicitly."
  }
}
