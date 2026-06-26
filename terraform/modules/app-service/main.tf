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
  name                = "app-${var.owner}-tf"
  resource_group_name = var.resource_group_name
  location            = data.azurerm_service_plan.plan.location
  service_plan_id     = var.service_plan_id
  https_only          = true

  site_config {
    minimum_tls_version = "1.2"
    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
    ENVIRONMENT                    = "tp"
  }

  tags = var.tags
}

data "azurerm_service_plan" "plan" {
  # Retrieves the plan location from its ID
  name                = split("/", var.service_plan_id)[8]
  resource_group_name = split("/", var.service_plan_id)[4]
}
