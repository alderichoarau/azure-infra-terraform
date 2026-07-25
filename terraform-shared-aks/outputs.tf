# Every output is keyed by environment (matches var.environments) so a student
# picks the right entry for their own `environment` var, e.g.:
#   terraform output -json cluster_name | jq -r '.nonprod'

output "cluster_name" {
  description = "AKS cluster name per environment — students reference this in their own data \"azurerm_kubernetes_cluster\" block."
  value       = { for env, c in azurerm_kubernetes_cluster.this : env => c.name }
}

output "cluster_id" {
  description = "AKS cluster resource ID per environment — needed to build the namespace-scoped Azure RBAC role assignment scope (\"<cluster_id>/namespaces/<ns>\") on the student side."
  value       = { for env, c in azurerm_kubernetes_cluster.this : env => c.id }
}

output "kubelet_identity_object_id" {
  description = "Object ID of each cluster's kubelet identity — grant this \"AcrPull\" on a student's own ACR so that cluster's nodes can pull that student's images."
  value       = { for env, c in azurerm_kubernetes_cluster.this : env => c.kubelet_identity[0].object_id }
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL per cluster — not used today (secrets flow via CI + kubectl, not Workload Identity), kept in case a future track switch wants pods to read Key Vault directly."
  value       = { for env, c in azurerm_kubernetes_cluster.this : env => c.oidc_issuer_url }
}

# The App Routing add-on's ingress controller gets its public IP from a
# Kubernetes-level LoadBalancer Service it creates itself inside the cluster
# (app-routing-system namespace) -- that's not a Terraform-computed attribute
# on azurerm_kubernetes_cluster, so there's no output for it here. After
# applying, fetch it with:
#   kubectl get svc -n app-routing-system -l app.kubernetes.io/name=nginx -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}'
# Students building nip.io hostnames (<owner>-backend.<ip>.nip.io) need this
# value — document it in the shared README once known post-apply, since it's
# stable as long as the cluster's LB Service isn't recreated.
