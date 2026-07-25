variable "shared_rg_name" {
  description = "Resource Group also holding ../terraform-shared-plan/'s App Service Plan (own state, same RG) — the AKS cluster(s) below join it rather than getting a new RG, same mutualised-infra convention, deliberately a different Terraform state (see main.tf's header comment). No default on purpose — comes from the AZURE_SHARED_RG_NAME GitHub secret (TF_VAR_shared_rg_name, deploy-terraform.yml) or an explicit -var locally, so this naming convention isn't hardcoded in the repo."
  type        = string
}

variable "location" {
  type    = string
  default = "francecentral"
}

# One cluster per environment, but only "nonprod" is actually created for now
# (var.environments controls this, not a hardcoded resource count) — apply
# again with `-var="environments=[\"nonprod\",\"prod\"]"` once ready to stand
# up the prod cluster too. Keeps main.tf's for_each unchanged either way.
variable "environments" {
  description = "Which AKS clusters to create in this apply. Cahier des charges calls for one cluster per environment (non-prod/prod) — starting with non-prod only."
  type        = list(string)
  default     = ["nonprod"]

  validation {
    condition     = alltrue([for e in var.environments : contains(["nonprod", "prod"], e)])
    error_message = "environments may only contain \"nonprod\" and/or \"prod\"."
  }
}

variable "cohort" {
  description = "Cohort/promo identifier used in resource names. No default on purpose — comes from the AZURE_COHORT GitHub secret (TF_VAR_cohort) or an explicit -var locally, so this naming convention isn't hardcoded in the repo."
  type        = string
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version. Left unset (null) by default to track whatever AKS currently defaults new clusters to; pin explicitly once the cluster exists if you need to control upgrade timing."
  type        = string
  default     = null
}

variable "node_vm_size" {
  description = "VM size for the system node pool. Standard_D2s_v3 chosen for the same reason as the Prometheus VM (../terraform-prometheus/variables.tf, prometheus_vm_size) — B-series sizes were found capacity-restricted on this subscription in francecentral."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "node_count" {
  description = "Fixed node count for the system pool (no autoscaling — keep this cheap and predictable for a training cluster shared by a whole cohort). Bump manually if pods start getting stuck Pending under load."
  type        = number
  default     = 2
}
