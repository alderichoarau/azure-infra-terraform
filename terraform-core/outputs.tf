# Read by ../terraform-python, ../terraform-managed-services and
# ../terraform-aks-app via:
#   data "terraform_remote_state" "core" {
#     backend = "remote"
#     config = {
#       organization = "alderic-hoarau"
#       workspaces   = { name = var.core_workspace_name }  # default "azure-core-alderic-hoarau"
#     }
#   }
# then referenced as data.terraform_remote_state.core.outputs.<name>.

output "owner" {
  description = "Learner identifier (var.owner) — re-exported so downstream directories don't have to duplicate the tfvars value."
  value       = var.owner
}

output "resource_group_name" {
  description = "Resource Group name (var.resource_group_name) — re-exported for the same reason."
  value       = var.resource_group_name
}

output "vnet_id" {
  description = "ID of the VNet (module.network)"
  value       = module.network.vnet_id
}

output "vnet_name" {
  description = "Name of the VNet — needed by any downstream subnet created outside this directory (e.g. ../terraform-managed-services's subnet-data/subnet-java-app)."
  value       = module.network.vnet_name
}

output "subnet_frontend_id" {
  description = "ID of subnet-frontend"
  value       = module.network.subnet_frontend_id
}

output "subnet_backend_id" {
  description = "ID of subnet-backend — where ../terraform-managed-services's Redis/Key Vault Private Endpoints attach."
  value       = module.network.subnet_backend_id
}

output "nsg_frontend_name" {
  description = "Name of the NSG attached to subnet-frontend"
  value       = module.network.nsg_frontend_name
}

output "storage_account_id" {
  description = "ID of the shared Storage Account (module.storage_shared) — needed by ../terraform-managed-services's storage-java.tf to create its container on this same account."
  value       = module.storage_shared.storage_account_id
}

output "storage_account_name" {
  description = "Name of the shared Storage Account"
  value       = module.storage_shared.storage_account_name
}

output "blob_container_private_url" {
  description = "URL of the private api-logs container"
  value       = module.storage_shared.private_container_url
}

output "blob_container_public_url" {
  description = "Public URL of the api-config container"
  value       = module.storage_shared.public_container_url
}

output "ci_app_deploy_client_id" {
  description = "Client ID of the User-Assigned Managed Identity used by azure-quiz-backend/azure-quiz-frontend's deploy(-aks).yml workflows. Put this value into both repos' AZURE_CLIENT_ID GitHub secret."
  value       = azurerm_user_assigned_identity.ci_app_deploy.client_id
}

output "ci_app_deploy_principal_id" {
  description = "Object ID (not client ID) of ci_app_deploy — ../terraform-managed-services (Key Vault Secrets User) and ../terraform-aks-app (AcrPush) both grant additional roles to this principal, scoped to their own track's resources. Also the value to give the trainer when asking them to run scripts/bootstrap-aks-namespace.sh."
  value       = azurerm_user_assigned_identity.ci_app_deploy.principal_id
}
