plugin "azurerm" {
  enabled = true
  version = "0.27.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
  # signature = "pgp" works around a tflint crash verifying sigstore attestation
  # bundles when GITHUB_TOKEN is set (upstream bug, tflint#2591 — July 2026).
  signature = "pgp"
}
