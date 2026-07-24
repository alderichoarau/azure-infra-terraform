# ──────────────────────────────────────────────────────────────────────────────
# redis.tf — Azure Managed Redis.
#
# TP Java/Angular — piste "services managés". Azure Cache for Redis (the older
# service) is closed to new creations — see
# https://aka.ms/AzureCacheForRedisRetirement — hence azurerm_managed_redis
# (requires azurerm >= 4.60, see providers.tf) instead of azurerm_redis_cache.
#
# public_network_access = "Disabled" means the Private Endpoint below is the
# only path in — no firewall/allow-list exception exists for this SKU family
# once disabled.
# ──────────────────────────────────────────────────────────────────────────────

resource "azurerm_managed_redis" "app" {
  name                = "redis-${var.owner}-tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  sku_name            = var.redis_sku_name

  public_network_access = "Disabled"

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

resource "azurerm_private_endpoint" "redis" {
  name                = "pe-redis-${var.owner}-tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  subnet_id           = module.network.subnet_backend_id
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
}
