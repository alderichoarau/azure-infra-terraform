#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# setup-cert-manager.sh — trainer-run, ONE-SHOT per shared cluster (not per
# learner, unlike bootstrap-aks-namespace.sh). Installs cert-manager +
# registers a Let's Encrypt ClusterIssuer on the shared AKS cluster so that
# every learner's nip.io Ingress hostname (<owner>-frontend/backend.<ip>.
# nip.io) can get a real, browser-trusted TLS cert instead of the App
# Routing add-on's self-signed default -- the recurring ERR_CERT_AUTHORITY_
# INVALID friction hit live while testing the AKS track.
#
# Why this works at all: nip.io is a real, publicly resolvable wildcard DNS
# domain (<anything>.<ip>.nip.io resolves to <ip> with zero config), so
# Let's Encrypt's HTTP-01 challenge -- which just needs to reach port 80 on
# the hostname being certified -- succeeds exactly like it would for a real
# domain. No Azure DNS zone, no azurerm_dns_zone, no --attach-zones needed
# (that Key-Vault-backed path in the AKS docs is for a *real* custom domain,
# a different, heavier mechanism than what's needed here).
#
# What it does:
#   1. Installs cert-manager (CRDs + controller) via its official Helm
#      chart, into its own 'cert-manager' namespace.
#   2. Applies a ClusterIssuer ('letsencrypt-prod') using the ACME HTTP-01
#      solver, routed through the App Routing add-on's own IngressClass
#      (webapprouting.kubernetes.azure.com) -- cert-manager spins up a
#      temporary solver Ingress on that same class to answer the challenge,
#      no separate ingress controller needed.
#
# Cluster-wide, benefits every learner on the AKS track with zero
# configuration on their side beyond the 2 lines added to their own
# Ingress (annotation + tls: block) -- already wired into this TP's
# reference Helm charts (quiz-backend/quiz-frontend), learners building
# their own charts from scratch can copy the same pattern.
#
# Prerequisites (on YOUR machine): az CLI logged in with rights on
# rg-shared-prf2026 (same admin kubeconfig access as
# bootstrap-aks-namespace.sh), kubectl, helm.
#
# Usage:
#   ./scripts/setup-cert-manager.sh [environment] [acme_email]
#
#   [environment]  nonprod (default) or prod.
#   [acme_email]   contact address Let's Encrypt uses for expiry/revocation
#                  notices -- defaults to alderic.hoarau@gmail.com.
#
# Re-running is safe (helm upgrade --install + kubectl apply, both
# idempotent) -- e.g. to bump the cert-manager version later.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

ENVIRONMENT="${1:-nonprod}"
ACME_EMAIL="${2:-alderic.hoarau@gmail.com}"

SHARED_RG="rg-shared-prf2026"
CLUSTER_NAME="aks-${ENVIRONMENT}-prf2026"
CERT_MANAGER_VERSION="v1.16.2"

for cmd in az kubectl helm; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "::error:: '$cmd' not found in PATH." >&2; exit 1; }
done

echo "→ Fetching admin credentials for $CLUSTER_NAME ($SHARED_RG) ..."
az aks get-credentials \
  --resource-group "$SHARED_RG" \
  --name "$CLUSTER_NAME" \
  --admin \
  --overwrite-existing

echo "→ Adding/updating the jetstack Helm repo ..."
helm repo add jetstack https://charts.jetstack.io --force-update
helm repo update jetstack

echo "→ Installing/upgrading cert-manager ($CERT_MANAGER_VERSION) ..."
# installCRDs=true: pulls in the Certificate/Issuer/ClusterIssuer/... CRDs as
# part of the release instead of a separate `kubectl apply` step -- one less
# thing to keep in sync across upgrades.
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version "$CERT_MANAGER_VERSION" \
  --set installCRDs=true \
  --wait

echo "→ Applying the Let's Encrypt ClusterIssuers (staging + prod) ..."
# HTTP-01 solver, routed through the App Routing add-on's own IngressClass --
# cert-manager creates a short-lived Ingress on this same class to answer
# each challenge, no dedicated ingress controller needed. ingressClassName
# (not the older 'class' field) is the field cert-manager >=1.12 recommends;
# 'class' only exists for ingress-gce compatibility.
#
# Two issuers, not just one: Let's Encrypt's *production* endpoint has a
# real rate limit (duplicate-certificate / per-registered-domain quotas) --
# fine for a cohort's actual usage, but easy to burn through while iterating
# on the Ingress templates themselves (every `helm upgrade` that changes the
# host triggers a new order). 'letsencrypt-staging' issues untrusted-by-
# browsers but rate-limit-free certs, for exactly that iteration phase --
# switch an Ingress's cluster-issuer annotation to -prod once it's working.
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: ${ACME_EMAIL}
    privateKeySecretRef:
      name: letsencrypt-staging-account-key
    solvers:
      - http01:
          ingress:
            ingressClassName: webapprouting.kubernetes.azure.com
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${ACME_EMAIL}
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
      - http01:
          ingress:
            ingressClassName: webapprouting.kubernetes.azure.com
EOF

echo
echo "→ Waiting for both ClusterIssuers to become Ready (registers the ACME accounts) ..."
kubectl wait --for=condition=Ready clusterissuer/letsencrypt-staging --timeout=60s
kubectl wait --for=condition=Ready clusterissuer/letsencrypt-prod --timeout=60s

echo
echo "Done. Any Ingress on $CLUSTER_NAME can now get a real Let's Encrypt cert by adding:"
echo '    annotations:'
echo '      cert-manager.io/cluster-issuer: letsencrypt-prod   # or letsencrypt-staging while iterating'
echo '    spec.tls:'
echo '      - hosts: [<its nip.io hostname>]'
echo '        secretName: <anything>-tls'
echo "Already wired into quiz-backend/quiz-frontend's Helm charts."
