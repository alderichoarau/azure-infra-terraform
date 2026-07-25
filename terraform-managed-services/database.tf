# ──────────────────────────────────────────────────────────────────────────────
# database.tf — PostgreSQL Flexible Server.
#
# TP Java/Angular. Connection info is pushed to Key Vault (keyvault.tf), never
# exposed as a plain Terraform output.
#
# Networking mode is a var.postgres_public_access-gated toggle between two
# mutually exclusive Postgres Flexible Server configurations (Azure forbids
# combining delegated_subnet_id with public_network_access_enabled = true —
# unlike Redis/Storage, there's no way to have both at once here):
#
#   - false (VNet-integrated, the original "services managés" setup): its own
#     delegated subnet-data (can't reuse subnet-backend — that one's delegated
#     to Microsoft.Web/serverFarms for the Web App's outbound VNet
#     Integration, and a subnet can only carry one service delegation) + a
#     private DNS zone, no public access at all.
#   - true (current default): public access + a firewall rule, no VNet
#     involvement. Needed for the AKS track — the shared cluster
#     (../terraform-shared-aks) lives outside this VNet with no peering (see
#     that directory's main.tf network note: peering would need a manual
#     trainer-side grant per learner, rights this apply's own identity
#     doesn't have on the trainer's shared RG, same as it can't grant itself
#     the AKS namespace RBAC role either). Credentials + TLS become the real
#     boundary here, same trade-off already made for Redis (redis.tf) and
#     backend<->frontend CORS (app-service-java.tf).
#
# Switch back with `-var="postgres_public_access=false"` once/if VNet peering
# ever becomes viable — every resource below is written to support either
# value cleanly, nothing to hand-edit.
# ──────────────────────────────────────────────────────────────────────────────

resource "azurerm_subnet" "data" {
  count = var.postgres_public_access ? 0 : 1

  name                 = "subnet-data"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = data.terraform_remote_state.core.outputs.vnet_name
  address_prefixes     = ["10.0.4.0/24"]

  delegation {
    name = "postgres-flexible-server"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_private_dns_zone" "postgres" {
  count = var.postgres_public_access ? 0 : 1

  name                = "${var.owner}-tf.postgres.database.azure.com"
  resource_group_name = data.azurerm_resource_group.rg.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  count = var.postgres_public_access ? 0 : 1

  name                  = "pdnslink-postgres-${var.owner}-tf"
  private_dns_zone_name = azurerm_private_dns_zone.postgres[0].name
  virtual_network_id    = data.terraform_remote_state.core.outputs.vnet_id
  resource_group_name   = data.azurerm_resource_group.rg.name
  tags                  = local.tags
}

# The magic 0.0.0.0-0.0.0.0 range is Azure's documented sentinel for "Allow
# public access from any Azure service within Azure to this server" — the
# same rule the portal's own checkbox creates. Meaningfully narrower than a
# real 0.0.0.0-255.255.255.255 "allow the whole internet" rule (AKS's outbound
# IP is dynamic/unpinned today, see the deploy-aks.yml TODO, so a real IP
# range isn't pinnable yet) while still covering the shared cluster's nodes.
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure_services" {
  count = var.postgres_public_access ? 1 : 0

  name             = "AllowAllAzureServicesAndResourcesWithinAzureIps"
  server_id        = azurerm_postgresql_flexible_server.app.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Only unreserved URL characters (RFC 3986) — this password is embedded directly
# in the connection-string secret (keyvault.tf) without URL-encoding, so anything
# in "@:/?#" would silently corrupt that string.
resource "random_password" "postgres_admin" {
  length           = 24
  special          = true
  override_special = "-_.~"
}

resource "azurerm_postgresql_flexible_server" "app" {
  name                = "psql-${var.owner}-tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  version             = var.postgres_version

  delegated_subnet_id           = var.postgres_public_access ? null : azurerm_subnet.data[0].id
  private_dns_zone_id           = var.postgres_public_access ? null : azurerm_private_dns_zone.postgres[0].id
  public_network_access_enabled = var.postgres_public_access

  administrator_login    = "pgadmin${replace(var.owner, "-", "")}"
  administrator_password = random_password.postgres_admin.result

  storage_mb   = 32768
  storage_tier = "P4"
  sku_name     = var.postgres_sku_name

  backup_retention_days = 7

  tags = local.tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]

  # Azure auto-assigns an availability zone at creation time even though it's
  # not set here (no high_availability block = no standby zone to "exchange"
  # with). On the next apply, the provider then sees state drift on `zone` and
  # errors with "zone can only be changed when exchanged with the zone
  # specified in high_availability.0.standby_availability_zone" — a known
  # azurerm provider limitation, not a real config problem. Ignore it.
  lifecycle {
    ignore_changes = [zone]
  }
}

resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = "appdb"
  server_id = azurerm_postgresql_flexible_server.app.id
  collation = "en_US.utf8"
  charset   = "UTF8"
}
