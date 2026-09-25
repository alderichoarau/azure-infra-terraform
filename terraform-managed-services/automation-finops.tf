# ──────────────────────────────────────────────────────────────────────────────
# automation-finops.tf — replaces the GitHub Actions-based nightly Postgres/App Service
# stop-start (finops-postgres-schedule.yml, this repo's own workflows) with an Azure
# Automation Runbook on its own native schedule.
#
# Why: GitHub Actions' `schedule` cron is queued on a shared global runner pool and can run
# significantly late under load (observed once: over 4 hours late on a cron pinned to the
# round hour, the busiest slot) -- Azure Automation's own scheduler isn't subject to that
# contention.
#
# Times are fixed UTC (22:00 stop / 06:00 start), same convention as the GitHub Actions cron
# it replaces -- no DST-following behavior, on purpose.
#
# Auth: System Assigned Managed Identity, Contributor on this Resource Group -- same scope
# the GitHub Actions OIDC service principal already had for this job, nothing narrower was
# built for either.
#
# Prod only, same as the resources it manages.
# ──────────────────────────────────────────────────────────────────────────────

resource "azurerm_automation_account" "finops" {
  count               = var.environment == "prod" ? 1 : 0
  name                = "aa-finops-${local.resource_suffix_compact}-tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  sku_name            = "Basic"

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}

resource "azurerm_role_assignment" "finops_contributor" {
  count                = var.environment == "prod" ? 1 : 0
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_automation_account.finops[0].identity[0].principal_id
}

# Runtime Environment pinning PowerShell 7.4 -- newer than the fixed "PowerShell72" runbook_type
# enum goes. runbook_type stays the generic "PowerShell" family marker; runtime_environment_name
# is what actually selects 7.4.
resource "azurerm_automation_runtime_environment" "powershell74" {
  count                 = var.environment == "prod" ? 1 : 0
  name                  = "powershell-7.4"
  automation_account_id = azurerm_automation_account.finops[0].id
  location              = var.location
  runtime_language      = "PowerShell"
  runtime_version       = "7.4"

  tags = local.tags
}

# Az.Accounts (incl. Invoke-AzRestMethod) is preloaded by default, so this deliberately talks to
# the ARM REST API directly rather than via Az.PostgreSql/Az.Websites cmdlets -- avoids depending
# on extra modules that aren't preinstalled and would need their own package resources (and the
# import time/version-pinning that comes with them).
resource "azurerm_automation_runbook" "postgres_app_service_schedule" {
  count                    = var.environment == "prod" ? 1 : 0
  name                     = "PostgresAppServiceSchedule"
  location                 = var.location
  resource_group_name      = data.azurerm_resource_group.rg.name
  automation_account_name  = azurerm_automation_account.finops[0].name
  log_verbose              = true
  log_progress             = true
  runbook_type             = "PowerShell"
  runtime_environment_name = azurerm_automation_runtime_environment.powershell74[0].name

  content = <<-POWERSHELL
    param(
        [Parameter(Mandatory=$true)][string]$SubscriptionId,
        [Parameter(Mandatory=$true)][string]$ResourceGroupName,
        [Parameter(Mandatory=$true)][string]$PostgresServerName,
        [Parameter(Mandatory=$true)][string]$WebAppName,
        [Parameter(Mandatory=$true)][ValidateSet("Stop","Start")][string]$Action
    )

    Connect-AzAccount -Identity | Out-Null

    $pgPath     = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DBforPostgreSQL/flexibleServers/$PostgresServerName"
    $webAppPath = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/sites/$WebAppName"

    function Invoke-Checked {
        param([string]$Path, [string]$Method, [string]$What)
        $r = Invoke-AzRestMethod -Path $Path -Method $Method
        if ($r.StatusCode -ge 300) {
            throw "$What failed (HTTP $($r.StatusCode)): $($r.Content)"
        }
        Write-Output "  $What -> HTTP $($r.StatusCode)"
        return $r
    }

    if ($Action -eq "Stop") {
        Write-Output "Stopping App Service $WebAppName..."
        Invoke-Checked -Path "$webAppPath/stop?api-version=2023-12-01" -Method POST -What "Stop App Service" | Out-Null

        Write-Output "Stopping Postgres $PostgresServerName..."
        Invoke-Checked -Path "$pgPath/stop?api-version=2024-08-01" -Method POST -What "Stop Postgres" | Out-Null
    }
    else {
        Write-Output "Starting Postgres $PostgresServerName..."
        Invoke-Checked -Path "$pgPath/start?api-version=2024-08-01" -Method POST -What "Start Postgres" | Out-Null

        Write-Output "Waiting for Postgres to be Ready..."
        $ready = $false
        for ($i = 0; $i -lt 30; $i++) {
            Start-Sleep -Seconds 10
            $resp = Invoke-Checked -Path "$pgPath`?api-version=2024-08-01" -Method GET -What "Get Postgres state"
            $state = ($resp.Content | ConvertFrom-Json).properties.state
            Write-Output "  state=$state"
            if ($state -eq "Ready") { $ready = $true; break }
        }
        if (-not $ready) {
            throw "Postgres did not reach 'Ready' within 5 minutes."
        }

        Write-Output "Starting App Service $WebAppName..."
        Invoke-Checked -Path "$webAppPath/start?api-version=2023-12-01" -Method POST -What "Start App Service" | Out-Null
    }

    Write-Output "Done: $Action complete."
  POWERSHELL

  tags = local.tags
}

resource "azurerm_automation_schedule" "stop" {
  count                   = var.environment == "prod" ? 1 : 0
  name                    = "nightly-stop"
  resource_group_name     = data.azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.finops[0].name
  frequency               = "Day"
  interval                = 1
  timezone                = "UTC"
  # Only the time-of-day/timezone matter for ongoing recurrence -- start_time itself just needs
  # to be in the future at apply time, see the lifecycle block below.
  start_time = "2026-09-26T22:00:00Z"

  lifecycle {
    ignore_changes = [start_time]
  }
}

resource "azurerm_automation_schedule" "start" {
  count                   = var.environment == "prod" ? 1 : 0
  name                    = "morning-start"
  resource_group_name     = data.azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.finops[0].name
  frequency               = "Day"
  interval                = 1
  timezone                = "UTC"
  start_time              = "2026-09-26T06:00:00Z"

  lifecycle {
    ignore_changes = [start_time]
  }
}

resource "azurerm_automation_job_schedule" "stop" {
  count                   = var.environment == "prod" ? 1 : 0
  resource_group_name     = data.azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.finops[0].name
  schedule_name           = azurerm_automation_schedule.stop[0].name
  runbook_name            = azurerm_automation_runbook.postgres_app_service_schedule[0].name

  parameters = {
    subscriptionid     = data.azurerm_client_config.current.subscription_id
    resourcegroupname  = data.azurerm_resource_group.rg.name
    postgresservername = azurerm_postgresql_flexible_server.app.name
    webappname         = azurerm_linux_web_app.java_app.name
    action             = "Stop"
  }
}

resource "azurerm_automation_job_schedule" "start" {
  count                   = var.environment == "prod" ? 1 : 0
  resource_group_name     = data.azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.finops[0].name
  schedule_name           = azurerm_automation_schedule.start[0].name
  runbook_name            = azurerm_automation_runbook.postgres_app_service_schedule[0].name

  parameters = {
    subscriptionid     = data.azurerm_client_config.current.subscription_id
    resourcegroupname  = data.azurerm_resource_group.rg.name
    postgresservername = azurerm_postgresql_flexible_server.app.name
    webappname         = azurerm_linux_web_app.java_app.name
    action             = "Start"
  }
}
