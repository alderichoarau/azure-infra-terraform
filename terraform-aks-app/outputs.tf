output "acr_login_server" {
  description = "Login server of this learner's Container Registry — used as the image prefix in azure-quiz-backend/frontend's deploy-aks.yml (e.g. <acr_login_server>/quiz-backend:<tag>)."
  value       = azurerm_container_registry.app.login_server
}

output "aks_namespace" {
  description = "Kubernetes namespace this learner's AKS-track resources should deploy into on the shared cluster (bootstrap-aks-namespace.sh creates it) — same value as var.owner, exposed here so deploy-aks.yml workflows don't have to duplicate that assumption."
  value       = var.owner
}
