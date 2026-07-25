variable "shared_rg_name" {
  description = "Resource Group already holding the shared App Service plan (../terraform/main.tf's shared_rg_name/shared_plan_name vars point here too) — the AKS cluster(s) below join it rather than getting a new RG, same mutualised-infra convention already used for the App Service plan."
  type        = string
  default     = "rg-shared-prf2026"
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
  description = "Cohort/promo identifier used in resource names, matches the rg-shared-prf2026 naming (\"prf2026\")."
  type        = string
  default     = "prf2026"
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version. Left unset (null) by default to track whatever AKS currently defaults new clusters to; pin explicitly once the cluster exists if you need to control upgrade timing."
  type        = string
  default     = null
}

variable "node_vm_size" {
  description = "VM size for the system node pool. Standard_D2s_v3 chosen for the same reason as the Prometheus VM (../terraform/variables.tf, prometheus_vm_size) — B-series sizes were found capacity-restricted on this subscription in francecentral."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "node_count" {
  description = "Fixed node count for the system pool (no autoscaling — keep this cheap and predictable for a training cluster shared by a whole cohort). Bump manually if pods start getting stuck Pending under load."
  type        = number
  default     = 2
}
