# ──────────────────────────────────────────────────────────────────────────────
# storage-java.tf — TP Java/Angular Storage requirement, on the EXISTING
# storage account (../terraform-core's module.storage_shared) rather than a
# new dedicated one.
#
# Trade-off, deliberate: the shared Storage Account has no network
# restriction (no Private Endpoint, public network access left at its default)
# because it already serves the Python observability TP's "api-config"
# container with intentional anonymous blob access — disabling public network
# access account-wide to satisfy "accessible uniquement depuis le backend"
# (cahier des charges §6) would break that existing, unrelated usage.
#
# So access here is enforced at the Azure AD / RBAC layer instead of the
# network layer: shared_access_key_enabled = false on the account (already the
# case, see ../terraform-core/storage.tf's module) means nobody gets in with
# an account key, only with an Azure AD identity holding a role on this
# specific container — and only the Java backend's managed identity gets one,
# below. Same category of trade-off as app-service-java.tf's CORS + API key
# for the same underlying reason (an existing shared resource whose other
# tenants can't be touched).
# ──────────────────────────────────────────────────────────────────────────────

resource "azurerm_storage_container" "java_uploads" {
  name                  = "java-uploads-${var.owner}"
  storage_account_id    = data.terraform_remote_state.core.outputs.storage_account_id
  container_access_type = "private"
}

resource "azurerm_role_assignment" "backend_storage_blob_contributor" {
  # Scoped to this one container, not the whole account — the Java backend's
  # identity has no access to api-logs/api-config, only to its own container.
  scope                = "${data.terraform_remote_state.core.outputs.storage_account_id}/blobServices/default/containers/${azurerm_storage_container.java_uploads.name}"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_web_app.java_app.identity[0].principal_id
}
