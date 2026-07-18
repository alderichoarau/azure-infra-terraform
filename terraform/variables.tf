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

variable "prometheus_vm_size" {
  description = "VM size for the Prometheus VM. Defaults to Standard_D2s_v3 (broadly available general-purpose size) rather than a B-series burstable size: on this training subscription, Standard_B1s hit a capacity restriction and every Standard_B*_v2 size is flagged NotAvailableForSubscription in francecentral (checked with `az vm list-skus --location francecentral --size Standard_B --resource-type virtualMachines --output table`) — a subscription-level block, not per-learner, so it would likely hit everyone the same way."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "trainer_ip_cidr" {
  description = "CIDR autorisé en SSH (22) sur la VM Prometheus — restreindre à l'IP de la salle/du formateur, jamais 0.0.0.0/0 en usage réel."
  type        = string

  validation {
    condition     = can(cidrhost(var.trainer_ip_cidr, 0))
    error_message = "trainer_ip_cidr must be a valid CIDR block, e.g. \"203.0.113.4/32\"."
  }
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
