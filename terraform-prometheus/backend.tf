# Separate workspace from ../terraform's "azure-infra-alderic-hoarau" -- this is
# the whole point of splitting this directory out: the Prometheus/Grafana/VM
# stack (the most expensive resources in this repo, meant to run 24/7 once
# turned on) gets its own independent apply/destroy cycle, decoupled from
# every other track. No more count = var.enable_prometheus_stack ? 1 : 0 on
# every resource (variables.tf used to carry that flag) -- applying or
# destroying THIS directory now IS the toggle.
#
# Rename the workspace name below if you're reusing this repo as your own
# template rather than Alderic's reference instance -- HCP Terraform Cloud
# workspace names in a `cloud` block are static strings, evaluated before any
# variable is available, so this can't be parameterized by var.owner.
terraform {
  cloud {
    organization = "alderic-hoarau"

    workspaces {
      name = "azure-prometheus-alderic-hoarau"
    }
  }
}
