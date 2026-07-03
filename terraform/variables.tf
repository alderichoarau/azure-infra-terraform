variable "owner" {
  description = "Learner identifier (firstname-lastname, lowercase, hyphens). Ex: john-doe"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]+[a-z0-9]$", var.owner))
    error_message = "owner must be lowercase, letters, digits and hyphens only."
  }
}

variable "resource_group_name" {
  description = "Name of the Resource Group pre-created by the trainer. Ex: rg-john-doe"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "francecentral"
}

variable "shared_rg_name" {
  description = "Resource Group containing the shared App Service plan"
  type        = string
  default     = "rg-shared-prf2026"
}

variable "shared_plan_name" {
  description = "Name of the shared App Service plan"
  type        = string
  default     = "plan-npr-prf2026"
}

variable "tags" {
  description = "Additional tags to merge with default tags"
  type        = map(string)
  default     = {}
}

variable "automation_only" {
  description = "Guard against accidental local apply/destroy — set to true only by the CI pipeline (TF_VAR_automation_only)."
  type        = bool

  validation {
    condition     = var.automation_only == true
    error_message = "plan/apply/destroy must run through the GitHub Actions pipeline. If you really mean to run this locally, pass -var=\"automation_only=true\" explicitly."
  }
}
