# This student's foundational state: network + shared storage account + the
# ci_app_deploy identity every app-repo deploy workflow authenticates with.
# Split out from the old monolithic "terraform" workspace so that
# ../terraform-python, ../terraform-managed-services and ../terraform-aks-app
# can each be applied/destroyed independently for cost control (per-track
# tracks toggled on/off without touching the network/storage/identity
# underneath them) while still sharing one VNet, one Storage Account and one
# CI identity — read cross-directory via terraform_remote_state (see each
# directory's main.tf).
#
# REQUIRED manual step after creating this workspace, before any apply from
# GitHub Actions or the CLI will work: in the workspace's Settings > General,
# set Execution Mode to "Local" (not the "Remote" default) — see
# ../terraform-shared-aks/backend.tf's comment for the full "az: executable
# file not found" story if this is skipped.
terraform {
  cloud {
    organization = "alderic-hoarau"

    workspaces {
      name = "azure-core-alderic-hoarau"
    }
  }
}
