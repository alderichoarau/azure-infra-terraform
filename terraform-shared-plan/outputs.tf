output "plan_id" {
  description = "ID of the shared App Service Plan — not actually needed by consumers, they look it up by name via data \"azurerm_service_plan\" \"shared\" instead (shared_rg_name/shared_plan_name vars), same pattern as ../terraform-shared-aks/'s cluster. Exposed here for convenience/debugging only."
  value       = azurerm_service_plan.shared.id
}

output "plan_name" {
  description = "Name of the shared App Service Plan (var.plan_name, default \"plan-npr-prf2026\") — keep ../terraform-python and ../terraform-managed-services's shared_plan_name var default in sync with this."
  value       = azurerm_service_plan.shared.name
}
