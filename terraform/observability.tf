# Observability stack: Log Analytics + Application Insights + Diagnostic Settings
# + Availability Tests + alerts, wired to app-service.tf / function-app.tf / storage.tf.

resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-${var.owner}-tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

resource "azurerm_application_insights" "app" {
  name                = "appi-app-${var.owner}-tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  workspace_id        = azurerm_log_analytics_workspace.law.id
  application_type    = "web"
  tags                = local.tags
}

resource "azurerm_application_insights" "func" {
  name                = "appi-func-${var.owner}-tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  workspace_id        = azurerm_log_analytics_workspace.law.id
  application_type    = "web"
  tags                = local.tags
}

# ── Diagnostic Settings ───────────────────────────────────────────────────────

resource "azurerm_monitor_diagnostic_setting" "app_service" {
  name                       = "diag-app-${var.owner}"
  target_resource_id         = module.app_service.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "function_app" {
  name                       = "diag-func-${var.owner}"
  target_resource_id         = module.function_app.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "storage_blob" {
  name                       = "diag-storage-blob-${var.owner}"
  target_resource_id         = "${module.storage.storage_account_id}/blobServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_metric {
    category = "AllMetrics"
  }
}

# ── Availability Tests ────────────────────────────────────────────────────────

resource "azurerm_application_insights_standard_web_test" "app_health" {
  name                    = "avail-app-${var.owner}"
  resource_group_name     = data.azurerm_resource_group.rg.name
  location                = var.location
  application_insights_id = azurerm_application_insights.app.id
  geo_locations           = ["emea-fr-pra-edge", "emea-nl-ams-azr", "emea-gb-db3-azr"]
  frequency               = 300
  timeout                 = 30
  tags                    = local.tags

  request {
    url = "https://${module.app_service.default_hostname}/health"
  }

  validation_rules {
    expected_status_code = 200
  }
}

resource "azurerm_application_insights_standard_web_test" "func_health" {
  name                    = "avail-func-${var.owner}"
  resource_group_name     = data.azurerm_resource_group.rg.name
  location                = var.location
  application_insights_id = azurerm_application_insights.func.id
  geo_locations           = ["emea-fr-pra-edge", "emea-nl-ams-azr", "emea-gb-db3-azr"]
  frequency               = 300
  timeout                 = 30
  tags                    = local.tags

  request {
    url = "https://${module.function_app.default_hostname}/api/http_trigger"
  }

  validation_rules {
    expected_status_code = 200
  }
}

# ── Action Group ──────────────────────────────────────────────────────────────

resource "azurerm_monitor_action_group" "team" {
  name                = "ag-${var.owner}-tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  short_name          = "team"

  email_receiver {
    name          = "equipe"
    email_address = var.alert_email
  }
}

# ── Alerts ─────────────────────────────────────────────────────────────────────
# Availability alerts (mandatory): app/func unreachable from 2+ of the 3 test regions.

resource "azurerm_monitor_metric_alert" "app_availability" {
  name                = "alert-avail-app-${var.owner}"
  resource_group_name = data.azurerm_resource_group.rg.name
  scopes = [
    azurerm_application_insights_standard_web_test.app_health.id,
    azurerm_application_insights.app.id
  ]
  severity    = 0 # Critical — the app is unreachable from the internet
  frequency   = "PT1M"
  window_size = "PT5M"

  application_insights_web_test_location_availability_criteria {
    web_test_id           = azurerm_application_insights_standard_web_test.app_health.id
    component_id          = azurerm_application_insights.app.id
    failed_location_count = 2
  }

  action {
    action_group_id = azurerm_monitor_action_group.team.id
  }
}

resource "azurerm_monitor_metric_alert" "func_availability" {
  name                = "alert-avail-func-${var.owner}"
  resource_group_name = data.azurerm_resource_group.rg.name
  scopes = [
    azurerm_application_insights_standard_web_test.func_health.id,
    azurerm_application_insights.func.id
  ]
  severity    = 0 # Critical — the function is unreachable from the internet
  frequency   = "PT1M"
  window_size = "PT5M"

  application_insights_web_test_location_availability_criteria {
    web_test_id           = azurerm_application_insights_standard_web_test.func_health.id
    component_id          = azurerm_application_insights.func.id
    failed_location_count = 2
  }

  action {
    action_group_id = azurerm_monitor_action_group.team.id
  }
}

# Metric alerts (chosen from the TP's suggested list, thresholds justified below).

resource "azurerm_monitor_metric_alert" "http5xx" {
  name                = "alert-http5xx-${var.owner}"
  resource_group_name = data.azurerm_resource_group.rg.name
  scopes              = [module.app_service.id]
  severity            = 1 # Error — not Critical, the app is still reachable
  frequency           = "PT1M"
  window_size         = "PT5M"

  # 5 server errors within a 5 min window filters out isolated blips while
  # still catching a real regression fast enough for the war-room exercise.
  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 5
  }

  action {
    action_group_id = azurerm_monitor_action_group.team.id
  }
}

resource "azurerm_monitor_metric_alert" "app_response_time" {
  name                = "alert-response-time-${var.owner}"
  resource_group_name = data.azurerm_resource_group.rg.name
  scopes              = [module.app_service.id]
  severity            = 2 # Warning — degraded, not yet an outage
  frequency           = "PT1M"
  window_size         = "PT5M"

  # 2s average response time over 5 min catches the /slow route regressing
  # without false-alerting on normal jitter. (CpuPercentage was considered
  # but it's a Microsoft.Web/serverFarms metric on the *shared* plan, not
  # the site — it would alert on every group's combined load, not just ours.)
  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "AverageResponseTime"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 2
  }

  action {
    action_group_id = azurerm_monitor_action_group.team.id
  }
}
