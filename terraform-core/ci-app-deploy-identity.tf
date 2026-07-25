# ──────────────────────────────────────────────────────────────────────────────
# ci-app-deploy-identity.tf — dedicated identity for the app repos' CI
# (azure-quiz-backend/frontend's deploy.yml AND deploy-aks.yml workflows),
# separate from whatever identity runs `terraform apply` for this repo (that
# one has much broader rights — User Access Administrator, etc. — no reason
# for the app deploy pipelines to hold those too).
#
# Lives in terraform-core, not a per-track directory: both the
# "services managés" track (../terraform-managed-services) and the "AKS"
# track (../terraform-aks-app) need this SAME identity to push
# secrets/images — Key Vault Secrets User (managed-services) and AcrPush
# (aks-app) role assignments are added onto it in each of those directories,
# scoped to that track's own resources, via this directory's
# ci_app_deploy_principal_id output.
#
# User-Assigned Managed Identity rather than an App Registration/Service
# Principal: no Microsoft Graph admin consent needed to create or manage it,
# it's a plain ARM resource like everything else here, and GitHub's OIDC
# federation supports it exactly the same way (client-id/tenant-id/
# subscription-id in azure/login@v3).
#
# Scope: Contributor on the whole Resource Group (data.azurerm_resource_group.rg)
# — explicit choice, not least-privilege. Simpler than granting the exact
# per-action roles (Key Vault Secrets User, Website Contributor scoped to one
# app, AcrPush scoped to one registry, Reader for the tag lookups) separately;
# the trade-off is this identity can touch anything in the RG, not just the
# Java backend/frontend resources — including resources created by tracks
# this directory itself has no knowledge of.
# ──────────────────────────────────────────────────────────────────────────────

resource "azurerm_user_assigned_identity" "ci_app_deploy" {
  name                = "id-ci-app-deploy-${var.owner}-tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  tags                = local.tags
}

resource "azurerm_role_assignment" "ci_app_deploy_contributor" {
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.ci_app_deploy.principal_id
}

# One federated credential per repo — GitHub's OIDC subject is
# repo:<org>/<repo>:ref:refs/heads/<branch>, so it's tied to both the exact
# repo AND the branch the workflow runs from. workflow_dispatch uses whichever
# branch/ref is selected at trigger time; deploy.yml/deploy-aks.yml are only
# ever triggered from main today. Triggering from another branch would need an
# extra federated credential for that ref.

resource "azurerm_federated_identity_credential" "backend_deploy" {
  name                      = "github-azure-quiz-backend-main"
  user_assigned_identity_id = azurerm_user_assigned_identity.ci_app_deploy.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:alderichoarau/azure-quiz-backend:ref:refs/heads/main"
}

resource "azurerm_federated_identity_credential" "frontend_deploy" {
  name                      = "github-azure-quiz-frontend-main"
  user_assigned_identity_id = azurerm_user_assigned_identity.ci_app_deploy.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:alderichoarau/azure-quiz-frontend:ref:refs/heads/main"
}
