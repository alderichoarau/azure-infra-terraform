# ──────────────────────────────────────────────────────────────────────────────
# main.tf — shared App Service Plan, trainer-side.
#
# TP Java/Angular + observabilité Python — one plan for the whole cohort,
# hosting every learner's Python App Service + Function App
# (../terraform-python) AND Java Web App (../terraform-managed-services).
# Used to be one dedicated plan per learner per app (plan-<owner>-tf,
# plan-java-<owner>-tf) — consolidated onto a single shared plan to cut cost:
# an App Service Plan is billed continuously regardless of how many apps sit
# on it, so mutualising it across every learner and every app is strictly
# cheaper than N dedicated plans.
#
# Deliberately its own directory/state, separate from
# ../terraform-shared-aks/'s cluster even though both are trainer-side/shared:
# this Plan is meant to stay up continuously for the whole cohort, while the
# cluster is the repo's most expensive resource and gets torn down/recreated
# between AKS-track sessions — the two must never be forced to live or die
# together (mixing them was tried and reverted for exactly this reason).
# ──────────────────────────────────────────────────────────────────────────────

data "azurerm_resource_group" "shared" {
  name = var.shared_rg_name
}

locals {
  # var.plan_sku's default (B3) is sized for the real cohort (many learners'
  # apps on one plan) — a personal prod plan hosting a single app doesn't
  # need that, so prod overrides down to B1 unless -var overrides it further.
  plan_sku = var.environment == "prod" ? "B1" : var.plan_sku
}

resource "azurerm_service_plan" "shared" {
  name                = var.plan_name
  resource_group_name = data.azurerm_resource_group.shared.name
  location            = var.location
  os_type             = "Linux"
  sku_name            = local.plan_sku

  tags = {
    managed_by = "terraform"
    scope      = "shared"
  }
}
