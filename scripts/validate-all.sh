#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# validate-all.sh — runs `terraform fmt`, `terraform init -backend=false` and
# `terraform validate` in every live Terraform directory in this repo, in
# turn. Same three checks as the "Validate" job in .github/workflows/ci.yml,
# just runnable locally before pushing instead of waiting on CI (the
# pre-commit hook already runs these per-file on commit; this script is for
# checking every directory at once, e.g. right after a refactor).
#
# `-backend=false`: skips talking to HCP Terraform Cloud (no state/run
# access needed just to check syntax) and skips Azure login entirely --
# fmt/init/validate never touch a real Azure subscription. You DO still need
# to have run `terraform login` at least once on this machine (stores a
# token in ~/.terraform.d/credentials.tfrc.json) -- module sources
# (app.terraform.io/alderic-hoarau/...) are a private registry, and even
# `-backend=false` still resolves module sources during init.
#
# `terraform fmt` here rewrites files in place (not `-check`) -- this script
# is meant for local cleanup before a commit, not as a CI gate. Use
# `terraform fmt -check -recursive` yourself (or let the pre-commit hook do
# it) if you just want to know whether formatting is needed without changing
# anything.
#
# terraform-legacy-retired is deliberately excluded -- every .tf file in it
# was renamed to *.tf.retired specifically so Terraform ignores it.
#
# Usage: run from the repo root, no arguments:
#   ./scripts/validate-all.sh
# ──────────────────────────────────────────────────────────────────────────────
set -uo pipefail

DIRECTORIES=(
  terraform-core
  terraform-python
  terraform-managed-services
  terraform-aks-app
  terraform-shared-aks
  terraform-shared-plan
  terraform-prometheus
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/.."

FAILED=()

for dir in "${DIRECTORIES[@]}"; do
  echo "──────────────────────────────────────────────"
  echo "→ $dir"
  echo "──────────────────────────────────────────────"

  if [ ! -d "$REPO_ROOT/$dir" ]; then
    echo "::warning:: '$dir' not found, skipping."
    continue
  fi

  (
    cd "$REPO_ROOT/$dir"
    set -e
    terraform fmt
    terraform init -backend=false -input=false
    terraform validate
  )

  if [ $? -ne 0 ]; then
    FAILED+=("$dir")
    echo "❌ $dir FAILED"
  else
    echo "✅ $dir OK"
  fi
  echo
done

echo "══════════════════════════════════════════════"
if [ ${#FAILED[@]} -eq 0 ]; then
  echo "All directories passed fmt/init/validate."
  exit 0
else
  echo "Failed: ${FAILED[*]}"
  exit 1
fi
