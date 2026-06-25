# Azure Container Instance — nginx:latest
# Mirror of step [5] in provision.sh

resource "azurerm_container_group" "aci" {
  name                = "aci-${var.owner}-tf"
  resource_group_name = var.resource_group_name
  location            = var.location
  ip_address_type     = "Public"
  dns_name_label      = "aci-${var.owner}-tf"
  os_type             = "Linux"

  container {
    name   = "nginx"
    image  = "nginx:latest"
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
