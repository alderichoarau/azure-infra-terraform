#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# sync-app-secrets.sh — pushes the 5 non-sensitive GitHub Actions secrets that
# azure-quiz-backend/.github/workflows/deploy.yml and
# azure-quiz-frontend/.github/workflows/swa-deploy.yml need (AZURE_CLIENT_ID,
# AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID, AZURE_RG_NAME, AZURE_OWNER) into both
# app repos in one shot, instead of copy-pasting each value through the GitHub
# UI by hand.
#
# None of these 5 values are actually secret material: with OIDC + federated
# credentials (ci-app-deploy-identity.tf) there is no client secret anywhere —
# the client-id/tenant-id/subscription-id only identify *which* identity to
# request a token for for; the federated credential (subject = exact repo +
# branch) is what actually grants access, and that lives in Azure, never in
# GitHub. Storing them as GitHub "secrets" here is just convention/hygiene, not
# because leaking them would grant access on its own.
#
# Prerequisites (on YOUR machine, not in any sandbox):
#   - az CLI, already logged in (`az login`) to the subscription this Resource
#     Group lives in
#   - gh CLI, already logged in (`gh auth login`) with a token that has repo
#     admin rights on both azure-quiz-backend and azure-quiz-frontend
#   - terraform, with this repo's state already applied (the outputs below
#     must exist)
#
# Usage: run from anywhere, no arguments:
#   ./scripts/sync-app-secrets.sh
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/../terraform"
GITHUB_ORG="alderichoarau"
REPOS=("azure-quiz-backend" "azure-quiz-frontend")

for cmd in az gh terraform; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "::error:: '$cmd' not found in PATH." >&2; exit 1; }
done

echo "Reading Terraform outputs from $TF_DIR ..."
CLIENT_ID=$(terraform -chdir="$TF_DIR" output -raw ci_app_deploy_client_id)
OWNER=$(terraform -chdir="$TF_DIR" output -raw owner)
RG_NAME=$(terraform -chdir="$TF_DIR" output -raw resource_group_name)

echo "Reading tenant/subscription from az CLI ..."
TENANT_ID=$(az account show --query tenantId -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

echo
echo "Values to push:"
echo "  AZURE_CLIENT_ID       = $CLIENT_ID"
echo "  AZURE_TENANT_ID       = $TENANT_ID"
echo "  AZURE_SUBSCRIPTION_ID = $SUBSCRIPTION_ID"
echo "  AZURE_RG_NAME         = $RG_NAME"
echo "  AZURE_OWNER           = $OWNER"
echo

for repo in "${REPOS[@]}"; do
  full="$GITHUB_ORG/$repo"
  echo "→ Syncing secrets into $full ..."
  gh secret set AZURE_CLIENT_ID       --repo "$full" --body "$CLIENT_ID"
  gh secret set AZURE_TENANT_ID       --repo "$full" --body "$TENANT_ID"
  gh secret set AZURE_SUBSCRIPTION_ID --repo "$full" --body "$SUBSCRIPTION_ID"
  gh secret set AZURE_RG_NAME         --repo "$full" --body "$RG_NAME"
  gh secret set AZURE_OWNER           --repo "$full" --body "$OWNER"
  echo "  done."
done

echo
echo "All 5 secrets synced into: ${REPOS[*]/#/$GITHUB_ORG/}"
