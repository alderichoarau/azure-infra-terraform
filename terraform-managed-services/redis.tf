# ──────────────────────────────────────────────────────────────────────────────
# redis.tf — Azure Managed Redis.
#
# TP Java/Angular — piste "services managés". Azure Cache for Redis (the older
# service) is closed to new creations — see
# https://aka.ms/AzureCacheForRedisRetirement — hence azurerm_managed_redis
# (requires azurerm >= 4.60, see providers.tf) instead of azurerm_redis_cache.
#
# public_network_access = "Enabled" (piste AKS): the shared AKS cluster
# (../terraform-aks-app, ../terraform-shared-aks) lives in its own VNet,
# outside this one, with no peering (see terraform-shared-aks/main.tf's
# network note — peering would need a manual trainer-side grant per learner,
# doesn't scale to a whole cohort). Access control here falls back to the
# primary access key (default_database below) + TLS as the real boundary,
# same trade-off already made and documented for backend<->frontend CORS
# (app-service-java.tf). App Service (managed-services track) is unaffected:
# the Private Endpoint + private DNS zone below still make anything inside
# this VNet resolve to the private IP regardless of this setting, so its
# traffic keeps taking the private path.
# ──────────────────────────────────────────────────────────────────────────────

resource "azurerm_managed_redis" "app" {
  name                = "redis-${var.owner}-tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  sku_name            = var.redis_sku_name

  public_network_access = "Enabled"

  default_database {
    # Off by default on this resource — without it, primary_access_key isn't
    # even exported, so the backend would have no credential to authenticate
    # with (client_protocol defaults to "Encrypted"/TLS, so a key is required
    # either way; Azure AD token auth would be the alternative but adds
    # complexity not worth it for this TP's single simple cache use case).
    access_keys_authentication_enabled = true
  }

  tags = local.tags
}


# "privatelink.redis.azure.net" is Microsoft's fixed private-DNS-zone name for
# Managed Redis / Redis Enterprise private-link targets (same mechanism as
# database.tf's postgres zone, but that resource sets private_dns_zone_id
# directly on the server -- Managed Redis has no such argument, so the zone
# has to be wired up through the Private Endpoint's private_dns_zone_group
# instead, same as Key Vault/Storage private endpoints elsewhere in Azure).
#
# Without this: the app's public FQDN (redis-<owner>-tf.<region>.redis.azure.net)
# is a CNAME to <name>.privatelink.redis.azure.net; with public_network_access
# = "Disabled" above and no matching zone linked to the VNet, that CNAME still
# resolves to the *public* IP from inside the App Service's VNet Integration
# subnet, and since public access is disabled, the connection just times out
# (packets silently dropped, not refused) -- exactly the ~10s ConnectTimeoutException
# hit during deployment. Linking this zone makes that same CNAME resolve to the
# Private Endpoint's private IP instead, for any client inside this VNet.
resource "azurerm_private_dns_zone" "redis" {
  name                = "privatelink.redis.azure.net"
  resource_group_name = data.azurerm_resource_group.rg.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "redis" {
  name                  = "pdnslink-redis-${var.owner}-tf"
  private_dns_zone_name = azurerm_private_dns_zone.redis.name
  virtual_network_id    = data.terraform_remote_state.core.outputs.vnet_id
  resource_group_name   = data.azurerm_resource_group.rg.name
  tags                  = local.tags
}

resource "azurerm_private_endpoint" "redis" {
  name                = "pe-redis-${var.owner}-tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  subnet_id           = data.terraform_remote_state.core.outputs.subnet_backend_id
  tags                = local.tags

  private_service_connection {
    name = "psc-redis-${var.owner}-tf"
    # "redisEnterprise" is the group ID for Managed Redis / Redis Enterprise
    # private-link targets (Microsoft.Cache/redisEnterprise). If this ever
    # rejects at apply time, confirm the current value with:
    #   az network private-link-resource list --id <redis_id> -o table
    private_connection_resource_id = azurerm_managed_redis.app.id
    subresource_names              = ["redisEnterprise"]
    is_manual_connection           = false
  }

  # Auto-creates/maintains the A record for this endpoint's private IP inside
  # the zone above -- same idea as Postgres's private_dns_zone_id, just
  # expressed through the Private Endpoint since Managed Redis doesn't have a
  # direct private_dns_zone_id argument of its own.
  private_dns_zone_group {
    name                 = "pdnszg-redis-${var.owner}-tf"
    private_dns_zone_ids = [azurerm_private_dns_zone.redis.id]
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.redis]
}
