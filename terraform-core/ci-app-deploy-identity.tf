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

# One pair of federated credentials per repo, subject on a GitHub Environment
# rather than a ref: repo:<org>/<repo>:environment:<name>. GitHub emits this
# subject for any job that declares `environment: <name>` — stable no matter
# which branch or tag actually triggered the run, unlike
# repo:<org>/<repo>:ref:refs/heads/<branch>|refs/tags/<tag> (a DIFFERENT
# subject per branch/tag, exact-match only, no wildcard support on this
# resource). That's what broke frontend's first tag-triggered release deploy
# (release-push.yml dispatches aks-deploy.yml/swa-deploy.yml pinned to a
# release tag, e.g. v1.1.0) with AADSTS700213 — no credential matched
# ref:refs/tags/v1.1.0. Every azure/login-using workflow in both app repos
# (aks-deploy.yml + asp-deploy.yml/swa-deploy.yml) now sets
# `environment: ${{ inputs.environment }}` on its job to match. Backend has no
# tag-triggered release workflow yet, but gets the same pair for consistency
# and so it's already covered the day one is added.
#
# Superseded the previous one-credential-per-branch setup (subjects
# repo:.../ref:refs/heads/main) -- removed below since nothing emits that
# subject anymore now that every workflow declares `environment:`.

resource "azurerm_federated_identity_credential" "backend_deploy_env_nonprod" {
  name                      = "github-azure-quiz-backend-env-nonprod"
  user_assigned_identity_id = azurerm_user_assigned_identity.ci_app_deploy.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:alderichoarau/azure-quiz-backend:environment:nonprod"
}

resource "azurerm_federated_identity_credential" "backend_deploy_env_prod" {
  name                      = "github-azure-quiz-backend-env-prod"
  user_assigned_identity_id = azurerm_user_assigned_identity.ci_app_deploy.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:alderichoarau/azure-quiz-backend:environment:prod"
}

resource "azurerm_federated_identity_credential" "frontend_deploy_env_nonprod" {
  name                      = "github-azure-quiz-frontend-env-nonprod"
  user_assigned_identity_id = azurerm_user_assigned_identity.ci_app_deploy.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:alderichoarau/azure-quiz-frontend:environment:nonprod"
}

resource "azurerm_federated_identity_credential" "frontend_deploy_env_prod" {
  name                      = "github-azure-quiz-frontend-env-prod"
  user_assigned_identity_id = azurerm_user_assigned_identity.ci_app_deploy.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:alderichoarau/azure-quiz-frontend:environment:prod"
}
