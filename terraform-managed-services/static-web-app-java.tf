# ──────────────────────────────────────────────────────────────────────────────
# static-web-app-java.tf — Angular frontend (TP Java/Angular).
#
# location is hard-pinned to "westeurope", deliberately not var.location: Static
# Web Apps only exist in a handful of regions worldwide (centralus, eastus2,
# westus2, westeurope, eastasia) — a hard limit of the service itself, not of
# this subscription. Forcing var.location here would break on any other region
# used for the rest of the stack (confirmed during TP validation: it failed
# outright in francecentral).
# ──────────────────────────────────────────────────────────────────────────────

resource "azurerm_static_web_app" "angular_frontend" {
  name                = "stapp-angular-${var.owner}-tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = "westeurope"
  sku_tier            = "Free"
  sku_size            = "Free"

  # component tag: lets the frontend/backend CI pipelines find this resource by
  # tag (owner + environment + component) instead of hardcoding its name —
  # names embed var.owner, which the app repos' CI shouldn't need to know.
  tags = merge(local.tags, { component = "quiz-frontend" })
}
