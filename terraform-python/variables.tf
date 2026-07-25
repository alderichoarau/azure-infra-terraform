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
  description = "Environment this deployment belongs to."
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
  description = "Resource Group containing the shared App Service plan (../terraform-shared-plan). No default on purpose — comes from the AZURE_SHARED_RG_NAME GitHub secret (TF_VAR_shared_rg_name, deploy-terraform.yml) or an explicit -var locally, so this naming convention isn't hardcoded in the repo."
  type        = string
}

variable "shared_plan_name" {
  description = "Name of the shared App Service plan (../terraform-shared-plan/variables.tf's plan_name — keep in sync). No default on purpose — comes from the AZURE_SHARED_PLAN_NAME GitHub secret (TF_VAR_shared_plan_name) or an explicit -var locally."
  type        = string
}

variable "core_workspace_name" {
  description = "HCP Terraform Cloud workspace name of ../terraform-core, read via terraform_remote_state for the VNet/Storage Account this track's resources attach to."
  type        = string
  default     = "azure-core-alderic-hoarau"
}

variable "alert_email" {
  description = "Email address that receives Azure Monitor alert notifications"
  type        = string

  validation {
    condition     = can(regex("^[^@]+@[^@]+\\.[^@]+$", var.alert_email))
    error_message = "alert_email must look like a valid email address."
  }
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
