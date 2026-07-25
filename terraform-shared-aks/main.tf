# ──────────────────────────────────────────────────────────────────────────────
# main.tf — mutualised AKS cluster(s), one per environment (var.environments).
#
# TP Java/Angular — piste "AKS", trainer-side. Same shared RG
# (rg-shared-prf2026) as ../terraform-shared-plan/'s App Service Plan, same
# idea: applied once by the trainer, referenced read-only by every student's
# own Terraform (../terraform-aks-app) via a data source, never applied
# per-student.
#
# Deliberately its OWN directory/state, separate from
# ../terraform-shared-plan/ even though both are trainer-side/shared/rarely
# touched: this cluster is the single most expensive resource in the whole
# repo (a control plane + node pool running continuously), while the App
# Service Plan is comparatively cheap and needed continuously by both the
# Python and Java tracks. Splitting them lets the cluster be destroyed
# between AKS-track sessions to cut cost, without dragging the Plan (and
# every learner's Python/Java app on it) down with it — the two resources
# must never be forced to live or die together.
#
# Network note (see conversation / cahier des charges §4.3): Postgres and
# Redis in each student's own RG are Private-Endpoint-only today, reachable
# only from inside that student's own VNet. This cluster deliberately does NOT
# peer into every student's VNet to preserve that isolation — doing so would
# need a manual trainer-side action (role assignment / group membership) for
# every single student, on top of the RG they already pre-create per student,
# which doesn't scale to a whole cohort. Instead, the AKS track's Postgres/
# Redis reachability is expected to fall back to public access + credentials/
# TLS as the real boundary (same trade-off already made and documented for
# backend<->frontend CORS in ../terraform/README.md) — implemented on the
# student side, not here.
# ──────────────────────────────────────────────────────────────────────────────

locals {
  tags = {
    managed_by = "terraform"
    scope      = "shared"
    cohort     = var.cohort
  }
}

# Resource Group pre-created by the trainer, same one ../terraform's
# shared_rg_name/shared_plan_name vars already point at for the shared App
# Service plan — never managed by Terraform (no azurerm_resource_group here).
data "azurerm_resource_group" "shared" {
  name = var.shared_rg_name
}

data "azurerm_client_config" "current" {}

resource "azurerm_kubernetes_cluster" "this" {
  for_each = toset(var.environments)

  name                = "aks-${each.key}-${var.cohort}"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.shared.name
  dns_prefix          = "aks-${each.key}-${var.cohort}"
  kubernetes_version  = var.kubernetes_version
  sku_tier            = "Free" # training cluster, no need for the Standard/Premium SLA tier

  default_node_pool {
    name       = "system"
    vm_size    = var.node_vm_size
    node_count = var.node_count
    # Azure CNI Overlay: pods get IPs from an internal overlay space instead of
    # burning real VNet addresses per pod — the right default for a new
    # cluster, and avoids needing a large dedicated subnet for a training
    # cluster nobody sized in advance.
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "azure"
    load_balancer_sku   = "standard"
  }

  identity {
    type = "SystemAssigned"
  }

  # Kubernetes-native RBAC stays on (default), but authorization is delegated
  # to Azure RBAC below — this is what lets each student's Terraform grant
  # their own ci_app_deploy identity a role scoped to just
  # "<this cluster>/namespaces/<their namespace>" instead of cluster-wide
  # access, which matters a lot on a cluster shared by an entire cohort.
  role_based_access_control_enabled = true
  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    # Required by the provider whenever azure_rbac_enabled = true (one of
    # tenant_id/admin_group_object_ids must be set) -- this tenant's Azure AD,
    # same one everything else in this cohort's subscription already lives
    # in. admin_group_object_ids intentionally left unset: no AAD group of
    # cluster-admins for a training cluster, access is granted per-namespace
    # instead (scripts/bootstrap-aks-namespace.sh, ../terraform/aks.tf).
    tenant_id = data.azurerm_client_config.current.tenant_id
  }

  # App Routing add-on: a managed NGINX ingress controller with zero Helm
  # install needed. dns_zone_ids = [] skips automatic public-DNS-zone
  # integration (no delegated zone for this training subscription) --
  # students get a plain LoadBalancer public IP off the ingress and can use
  # nip.io-style hostnames (<owner>.<ip>.nip.io) instead of real DNS.
  # NOTE: confirm this block's exact shape (dns_zone_id vs dns_zone_ids)
  # against the azurerm ~> 4.60 docs at `terraform plan` time -- this API
  # shape changed between provider versions.
  web_app_routing {
    dns_zone_ids = []
  }

  tags = local.tags
}
