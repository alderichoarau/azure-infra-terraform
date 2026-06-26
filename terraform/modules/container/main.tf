# Azure Container Instance — nginx:1.27-alpine
# Mirror of step [5] in provision.sh

terraform {
  required_version = ">= 1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# checkov:skip=CKV_AZURE_245: ACI exposé publiquement intentionnellement — conteneur nginx de démonstration TP
resource "azurerm_container_group" "aci" {
  name                = "aci-${var.owner}-tf"
  resource_group_name = var.resource_group_name
  location            = var.location
  ip_address_type     = "Public"
  dns_name_label      = "aci-${var.owner}-tf"
  os_type             = "Linux"

  container {
    name   = "nginx"
    image  = "nginx:1.27-alpine"
    cpu    = 0.5
    memory = 0.5

    ports {
      port     = 80
      protocol = "TCP"
    }

    environment_variables = {
      OWNER       = var.owner
      ENVIRONMENT = "tp"
    }
  }

  tags = var.tags
}
