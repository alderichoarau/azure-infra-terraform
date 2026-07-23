# ──────────────────────────────────────────────────────────────────────────────
# database.tf — PostgreSQL Flexible Server, VNet-integrated, no public access.
#
# TP Java/Angular — piste "services managés". Connection info is pushed to
# Key Vault (keyvault.tf), never exposed as a plain Terraform output.
#
# Gotcha: this needs its OWN delegated subnet (subnet-data). It cannot reuse
# subnet-backend (module.network) — that subnet is meant for the Web App's
# outbound VNet Integration (delegated to Microsoft.Web/serverFarms), and a
# subnet can only carry a single service delegation. Mixing the two would fail
# at apply time with a delegation conflict.
# ──────────────────────────────────────────────────────────────────────────────

resource "azurerm_subnet" "data" {
  name                 = "subnet-data"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = module.network.vnet_name
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
  name                = "${var.owner}-tf.postgres.database.azure.com"
  resource_group_name = data.azurerm_resource_group.rg.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "pdnslink-postgres-${var.owner}-tf"
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = module.network.vnet_id
  resource_group_name   = data.azurerm_resource_group.rg.name
  tags                  = local.tags
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

  delegated_subnet_id           = azurerm_subnet.data.id
  private_dns_zone_id           = azurerm_private_dns_zone.postgres.id
  public_network_access_enabled = false

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
