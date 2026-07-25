# ──────────────────────────────────────────────────────────────────────────────
# aks.tf — TP Java/Angular, piste "AKS".
#
# What lives here (self-service, this apply): the ACR that holds this
# learner's container images, and the AcrPull grant letting the shared
# cluster's nodes pull from it.
#
# What does NOT live here, on purpose: creating the Kubernetes namespace
# itself, and the namespace-scoped Azure RBAC role assignment that lets
# ci_app_deploy manage objects inside it. Both need rights on the *shared*
# cluster (../terraform-shared-aks, a different Resource Group this apply's
# identity has no access to) — same trust boundary as the Resource Group
# itself (data.azurerm_resource_group.rg, main.tf: "pre-created by the
# trainer, never managed by Terraform"). The trainer runs
# scripts/bootstrap-aks-namespace.sh once per learner instead — see that
# script and ../terraform-shared-aks/README.md for the full reasoning (a
# shared multi-tenant cluster fundamentally needs one trust-establishing step
# from whoever owns it, same as RG pre-creation already does for everything
# else in this repo).
# ──────────────────────────────────────────────────────────────────────────────

# Same cluster the trainer created in terraform-shared-aks/ — naming
# convention (aks-<environment>-<cohort>) must match that module's
# azurerm_kubernetes_cluster.this[each.key].name exactly.
data "azurerm_kubernetes_cluster" "shared" {
  name                = "aks-${var.environment}-${var.cohort}"
  resource_group_name = var.shared_rg_name
}

# Basic SKU: cheapest tier, no geo-replication/content-trust needed for a
# training registry holding a handful of image tags. admin_enabled = false —
# same RBAC-only philosophy already used for the Storage Accounts
# (storage_use_azuread, providers.tf) and Key Vault (RBAC, not access
# policies) elsewhere in this repo: push/pull goes through Azure AD
# identities, never a shared admin username/password.
resource "azurerm_container_registry" "app" {
  name                = "acr${replace(var.owner, "-", "")}tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = false

  # component = "quiz-registry", not "quiz-backend" -- both
  # azure-quiz-backend/frontend's deploy-aks.yml look this ACR up by tag
  # (same az resource list --query pattern as deploy.yml/swa-deploy.yml), so
  # it needs its own component value distinct from either app.
  tags = merge(local.tags, { component = "quiz-registry" })
}

# Lets the shared cluster's nodes pull this learner's images. Scoped to just
# this one ACR (in this learner's own RG) — self-service, no shared-cluster
# rights needed, unlike the namespace/RBAC bootstrap above.
resource "azurerm_role_assignment" "shared_aks_acr_pull" {
  scope                = azurerm_container_registry.app.id
  role_definition_name = "AcrPull"
  principal_id         = data.azurerm_kubernetes_cluster.shared.kubelet_identity[0].object_id
}

# ci_app_deploy (ci-app-deploy-identity.tf) also needs to push images to this
# ACR from azure-quiz-backend/frontend's deploy-aks.yml — AcrPush, same
# self-service scope.
resource "azurerm_role_assignment" "ci_app_deploy_acr_push" {
  scope                = azurerm_container_registry.app.id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_user_assigned_identity.ci_app_deploy.principal_id
}
