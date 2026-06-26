# Python App Service — uses the shared plan (data source in main.tf)
# Mirror of step [2] in provision.sh

terraform {
  required_version = ">= 1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

resource "azurerm_linux_web_app" "app" {
  # checkov:skip=CKV_AZURE_13: App Service Authentication (B2C) hors périmètre TP
  # checkov:skip=CKV_AZURE_17: Client certificates hors périmètre TP
  # checkov:skip=CKV_AZURE_78: FTP désactivé via ftp_publish_basic_authentication_enabled (azurerm 4.x)
  # checkov:skip=CKV_AZURE_88: Azure Files storage hors périmètre TP
  # checkov:skip=CKV_AZURE_222: accès réseau public requis pour le TP
  name                                     = "app-${var.owner}-tf"
  resource_group_name                      = var.resource_group_name
  location                                 = data.azurerm_service_plan.plan.location
  service_plan_id                          = var.service_plan_id
  https_only                               = true
  ftp_publish_basic_authentication_enabled = false

  identity {
    type = "SystemAssigned"
  }

  site_config {
    minimum_tls_version = "1.2"
    http2_enabled       = true
    health_check_path                 = "/health"
    health_check_eviction_time_in_min = 5
    application_stack {
      python_version = "3.11"
    }
  }

  logs {
    detailed_error_messages = true
    failed_request_tracing  = true
    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
  }

  app_settings = {
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
    ENVIRONMENT                    = "tp"
  }

  tags = var.tags
}

data "azurerm_service_plan" "plan" {
  name                = split("/", var.service_plan_id)[8]
  resource_group_name = split("/", var.service_plan_id)[4]
}
