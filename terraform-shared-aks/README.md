# terraform-shared-aks

Mutualised AKS cluster(s) for the TP Java/Angular "AKS" track — **trainer-side only**.
Students never apply this; they reference the cluster it creates via a read-only
data source in their own `../terraform` workspace (same pattern already used for
the shared App Service plan, `shared_rg_name`/`shared_plan_name` in
`../terraform/variables.tf`).

## Who runs this, and when

You (the trainer), rarely: once to stand up the non-prod cluster for a cohort,
again whenever you're ready to add the prod cluster
(`-var='environments=["nonprod","prod"]'`), and occasionally for version bumps.
Not part of any student's per-RG apply/destroy cycle — this lives in its own HCP
Terraform Cloud workspace (`azure-shared-aks-prf2026`) precisely so a student
`terraform destroy` in their own workspace can never touch it.

## First-time setup

1. Create the HCP Terraform Cloud workspace `azure-shared-aks-prf2026` in the
   `alderic-hoarau` org (UI, or let `terraform init` offer to create it).
2. `az login` with an identity that has Contributor (or better) on
   `rg-shared-prf2026`.
3. `terraform init && terraform plan` — review, then `terraform apply`.

## After applying

- `terraform output cluster_name` / `cluster_id` / `kubelet_identity_object_id` —
  students' `../terraform` AKS-track resources (not yet added — see main repo's
  task list) will need these values, most likely via new
  `shared_aks_cluster_name_nonprod` / `_prod` vars mirroring
  `shared_plan_name`'s convention, defaulted from this module's outputs.
- Grab the ingress controller's public IP (see the comment in `outputs.tf` for
  the exact `kubectl` command) and note it down somewhere students can find it —
  they'll build `nip.io` hostnames from it for their Ingress resources.

## Why a separate cluster's worth of complexity instead of just adding AKS to the shared App Service plan's RG data source

Because unlike the App Service plan (one resource, referenced directly), the
AKS track needs several things students provision themselves against this
cluster (namespace, Azure RBAC role assignment scoped to that namespace, an
ACR + AcrPull grant to this cluster's kubelet identity) — the cluster itself
is the only piece that has to be centrally owned and can't reasonably be
per-student.

## Known trade-off: network isolation to Postgres/Redis

This cluster does **not** VNet-peer into every student's own VNet. Doing so
would need a manual trainer-side step (role assignment or group membership)
per student on top of RG pre-creation, which doesn't scale across a cohort.
The AKS track's Postgres/Redis reachability is expected to rely on public
access + credentials/TLS instead — see the network note at the top of
`main.tf`, and `../terraform/README.md`'s existing writeup of the same
trade-off already made for backend↔frontend CORS in the managed-services
track.
