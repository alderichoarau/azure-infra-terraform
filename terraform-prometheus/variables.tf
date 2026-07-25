variable "owner" {
  description = "Learner identifier -- must match ../terraform-core's var.owner exactly, both for consistent resource naming and because that's whose Resource Group this stack deploys into."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]+[a-z0-9]$", var.owner))
    error_message = "owner must be lowercase, letters, digits and hyphens only."
  }
}

variable "resource_group_name" {
  description = "Same Resource Group as ../terraform-core -- this stack lives alongside the rest of the learner's infra, not a separate one."
  type        = string
}

variable "location" {
  type    = string
  default = "francecentral"
}

variable "environment" {
  type    = string
  default = "nonprod"

  validation {
    condition     = contains(["nonprod", "prod"], var.environment)
    error_message = "environment must be either \"nonprod\" or \"prod\"."
  }
}

variable "core_workspace_name" {
  description = "HCP Terraform Cloud workspace name of ../terraform-core -- read via terraform_remote_state (main.tf) for the VNet name this stack's dedicated subnet attaches to."
  type        = string
  default     = "azure-core-alderic-hoarau"
}

variable "python_workspace_name" {
  description = "HCP Terraform Cloud workspace name of ../terraform-python -- read via terraform_remote_state (main.tf) for the Python App Service's hostname (scrape target) and the shared \"team\" Action Group's ID (so alerts land in the same place as observability.tf's, no duplicate Action Group)."
  type        = string
  default     = "azure-python-alderic-hoarau"
}

variable "trainer_ip_cidr" {
  description = "CIDR autorisé en SSH (22) sur la VM Prometheus."
  type        = string

  validation {
    condition     = can(cidrhost(var.trainer_ip_cidr, 0))
    error_message = "trainer_ip_cidr must be a valid CIDR block, e.g. \"203.0.113.4/32\"."
  }
}

variable "prometheus_vm_size" {
  description = "VM size for the Prometheus VM. Standard_D2s_v3 default -- B-series sizes were found capacity-restricted on this subscription in francecentral."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "tags" {
  type    = map(string)
  default = {}
}

# tflint-ignore: terraform_unused_declarations
variable "automation_only" {
  description = "Guard against accidental local apply/destroy -- set to true only by the CI pipeline (TF_VAR_automation_only)."
  type        = bool

  validation {
    condition     = var.automation_only == true
    error_message = "plan/apply/destroy must run through the GitHub Actions pipeline. If you really mean to run this locally, pass -var=\"automation_only=true\" explicitly."
  }
}
