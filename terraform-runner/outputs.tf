output "runner_vm_public_ip" {
  description = "Public IP of the runner VM -- pass to azure-infra-ansible's run-playbook workflow."
  value       = azurerm_public_ip.runner_vm.ip_address
}

output "runner_ssh_private_key" {
  description = "Terraform-generated SSH private key for the runner VM (admin_username = azureuser). Copy this into azure-infra-ansible's RUNNER_SSH_PRIVATE_KEY secret -- `terraform output -raw runner_ssh_private_key`."
  value       = tls_private_key.runner_vm.private_key_openssh
  sensitive   = true
}
