output "monitor_workspace_id" {
  description = "ID of the Azure Monitor Workspace (managed Prometheus) — use to open Prometheus Explorer in the portal."
  value       = azurerm_monitor_workspace.amw.id
}

output "grafana_endpoint" {
  description = "URL of the Azure Managed Grafana instance."
  value       = azurerm_dashboard_grafana.grafana.endpoint
}

output "monitor_workspace_dce_id" {
  description = "ID of the auto-created Data Collection Endpoint — used for manual `az monitor data-collection endpoint show --ids ...` troubleshooting on the Prometheus VM."
  value       = azurerm_monitor_workspace.amw.default_data_collection_endpoint_id
}

output "monitor_workspace_dcr_id" {
  description = "ID of the auto-created Data Collection Rule — used for manual `az monitor data-collection rule show --ids ...` troubleshooting on the Prometheus VM."
  value       = azurerm_monitor_workspace.amw.default_data_collection_rule_id
}

output "prometheus_vm_public_ip" {
  description = "Public IP of the Prometheus VM — for SSH troubleshooting only, the remote_write pipeline is self-configuring via cloud-init."
  value       = azurerm_public_ip.prometheus_vm.ip_address
}

output "prometheus_vm_ssh_private_key" {
  description = "Terraform-generated SSH private key for the Prometheus VM (admin_username = azureuser). Save it locally with `terraform output -raw prometheus_vm_ssh_private_key > id_rsa && chmod 600 id_rsa` before connecting."
  value       = tls_private_key.prometheus_vm.private_key_openssh
  sensitive   = true
}
