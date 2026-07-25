#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# bootstrap-aks-namespace.sh — trainer-run, once per learner picking the AKS
# track. Not something a learner runs themselves: creating a Namespace object
# is a cluster-scoped Kubernetes operation, and granting a role assignment on
# the shared cluster needs rights outside any single learner's own Resource
# Group — same trust boundary as pre-creating a learner's RG in the first
# place (see terraform/aks.tf's header comment and
# ../terraform-shared-aks/README.md for the full reasoning).
#
# What it does:
#   1. Creates the learner's namespace on the shared AKS cluster (idempotent).
#   2. Grants their ci_app_deploy identity "Azure Kubernetes Service Cluster
#      User Role" on the cluster itself -- the ARM-level role needed just to
#      run `az aks get-credentials` (non-admin) and get a kubeconfig at all;
#      grants zero Kubernetes API access on its own.
#   3. Grants that same identity "Azure Kubernetes Service RBAC Admin",
#      scoped to just their one namespace -- the separate Kubernetes-
#      authorization layer (Azure RBAC for Kubernetes) controlling what they
#      can actually do with that kubeconfig once they have it. Both roles are
#      needed together: 2 without 3 gets a kubeconfig that can't do anything;
#      3 without 2 means deploy-aks.yml's `az aks get-credentials` step fails
#      with AuthorizationFailed before kubectl ever runs (hit this live).
#
# Prerequisites (on YOUR machine): az CLI logged in with rights on
# rg-shared-prf2026 (Azure Kubernetes Service Cluster Admin Role at least,
# to fetch the admin kubeconfig below), kubectl.
#
# Usage:
#   ./scripts/bootstrap-aks-namespace.sh <owner> <ci_app_deploy_principal_id> [environment]
#
#   <owner>                       learner identifier, e.g. jean-dupont — becomes
#                                 the namespace name (must match var.owner in
#                                 their terraform/terraform.tfvars).
#   <ci_app_deploy_principal_id>  object ID (NOT client ID) of their
#                                 ci_app_deploy identity — they get this from
#                                 `terraform output ci_app_deploy_principal_id`
#                                 in their own azure-infra-terraform apply.
#   [environment]                 nonprod (default) or prod.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

OWNER="${1:?Usage: $0 <owner> <ci_app_deploy_principal_id> [environment]}"
PRINCIPAL_ID="${2:?Usage: $0 <owner> <ci_app_deploy_principal_id> [environment]}"
ENVIRONMENT="${3:-nonprod}"

SHARED_RG="rg-shared-prf2026"
CLUSTER_NAME="aks-${ENVIRONMENT}-prf2026"

for cmd in az kubectl; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "::error:: '$cmd' not found in PATH." >&2; exit 1; }
done

echo "→ Fetching admin credentials for $CLUSTER_NAME ($SHARED_RG) ..."
# --admin: this script is trainer-only tooling, trusted with the cluster's
# local admin kubeconfig to bootstrap access for everyone else — learners
# never get this, only the namespace-scoped role assignment granted below.
az aks get-credentials \
  --resource-group "$SHARED_RG" \
  --name "$CLUSTER_NAME" \
  --admin \
  --overwrite-existing

echo "→ Creating namespace '$OWNER' (idempotent) ..."
kubectl create namespace "$OWNER" --dry-run=client -o yaml | kubectl apply -f -

echo "→ Resolving cluster resource ID ..."
CLUSTER_ID=$(az aks show --resource-group "$SHARED_RG" --name "$CLUSTER_NAME" --query id -o tsv)

echo "→ Granting 'Azure Kubernetes Service Cluster User Role' on the cluster to principal $PRINCIPAL_ID ..."
az role assignment create \
  --role "Azure Kubernetes Service Cluster User Role" \
  --scope "$CLUSTER_ID" \
  --assignee-object-id "$PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal

echo "→ Granting 'Azure Kubernetes Service RBAC Admin' on namespace '$OWNER' to principal $PRINCIPAL_ID ..."
az role assignment create \
  --role "Azure Kubernetes Service RBAC Admin" \
  --scope "${CLUSTER_ID}/namespaces/${OWNER}" \
  --assignee-object-id "$PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal

echo "→ Granting 'Azure Kubernetes Service RBAC Reader' on namespace 'app-routing-system' (ingress IP discovery) ..."
az role assignment create \
  --role "Azure Kubernetes Service RBAC Reader" \
  --scope "${CLUSTER_ID}/namespaces/app-routing-system" \
  --assignee-object-id "$PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal

echo
echo "Done. '$OWNER' can now deploy into namespace '$OWNER' on $CLUSTER_NAME via their ci_app_deploy identity."
