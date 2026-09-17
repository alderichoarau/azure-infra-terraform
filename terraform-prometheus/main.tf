# ──────────────────────────────────────────────────────────────────────────────
# Observability stack, part 2: managed Prometheus (Azure Monitor) + managed Grafana,
# alongside observability.tf (../terraform-python: Log Analytics, App Insights,
# Availability Tests, alerts).
#
# Own directory/state (backend.tf): these are the repo's most expensive resources,
# meant to run 24/7 once enabled -- applying/destroying this directory is the toggle.
#
# Separate from observability.tf: different signal (custom /metrics vs traces/requests).
#
# Gotcha: azurerm_monitor_workspace's Data Collection Rule lives in an Azure-managed
# resource group (e.g. "MA_amw-<owner>-tf_<region>_managed"), not in
# data.azurerm_resource_group.rg -- so "User Access Administrator" on the learner's own
# RG doesn't cover it. The apply principal needs that role (or "Role Based Access
# Control Administrator") at the SUBSCRIPTION level, or
# azurerm_role_assignment.prometheus_publisher fails 403 even with Contributor + UAA
# on the RG.
#
# remote_write auth is Microsoft-validated for VM/VMSS/AKS with a managed identity,
# not yet Container Apps -- hence a VM here. See
# https://learn.microsoft.com/azure/azure-monitor/metrics/prometheus-remote-write
# ──────────────────────────────────────────────────────────────────────────────

locals {
  tags = merge(
    {
      managed_by  = "terraform"
      environment = var.environment
      owner       = var.owner
    },
    var.tags
  )
}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

# Values this stack needs but doesn't own, split across two upstream states:
# ../terraform-core's outputs.tf exports vnet_name (this stack's dedicated
# subnet attaches to it); ../terraform-python's outputs.tf exports
# app_service_hostname (raw, for the cloud-init scrape target) and
# action_group_id (so alerts land in the same "team" Action Group as
# observability.tf's, no duplicate). Requires both to have been applied at
# least once already -- this stack can't come up before either of them.
data "terraform_remote_state" "core" {
  backend = "remote"

  config = {
    organization = "alderic-hoarau"
    workspaces = {
      name = var.core_workspace_name
    }
  }
}

data "terraform_remote_state" "python" {
  backend = "remote"

  config = {
    organization = "alderic-hoarau"
    workspaces = {
      name = var.python_workspace_name
    }
  }
}

# ── Azure Monitor Workspace (managed Prometheus) ──────────────────────────────

resource "azurerm_monitor_workspace" "amw" {
  name                = "amw-${var.owner}-tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  tags                = local.tags
}

# ── Managed Grafana ────────────────────────────────────────────────────────────

resource "azurerm_dashboard_grafana" "grafana" {
  # Azure Managed Grafana requires a 2-23 char name (letters/digits/hyphens).
  name                  = substr("grafana${replace(var.owner, "-", "")}", 0, 23)
  resource_group_name   = data.azurerm_resource_group.rg.name
  location              = var.location
  grafana_major_version = "12" # valid versions change over time -- Azure's error message lists current ones if this breaks
  tags                  = local.tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "grafana_monitoring_reader" {
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_dashboard_grafana.grafana.identity[0].principal_id
}

# ── Dedicated network for the Prometheus VM ───────────────────────────────────
# Own subnet rather than subnet-backend (../terraform-core): that one's NSG uses
# inline security_rule blocks, and mixing those with standalone
# azurerm_network_security_rule on the same NSG is unstable in practice.
#
# 10.0.3.0/24: free in the VNet's 10.0.0.0/16, next to subnet-frontend
# (10.0.1.0/24) and subnet-backend (10.0.2.0/24).

resource "azurerm_subnet" "prometheus" {
  name                 = "subnet-prometheus"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = data.terraform_remote_state.core.outputs.vnet_name
  address_prefixes     = ["10.0.3.0/24"]
}

resource "azurerm_network_security_group" "prometheus_vm" {
  # checkov:skip=CKV_AZURE_10: SSH open for troubleshooting -- restrict to the
  # training room's IP in real use, see var.trainer_ip_cidr
  name                = "nsg-prometheus-${var.owner}-tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  tags                = local.tags

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.trainer_ip_cidr
    destination_address_prefix = "*"
  }

  # No explicit outbound rule: Azure's defaults are enough (the VM needs
  # outbound internet -- apt, Prometheus binary, ARM, scrape, remote_write).
}

resource "azurerm_subnet_network_security_group_association" "prometheus" {
  subnet_id                 = azurerm_subnet.prometheus.id
  network_security_group_id = azurerm_network_security_group.prometheus_vm.id
}

resource "azurerm_public_ip" "prometheus_vm" {
  # checkov:skip=CKV_AZURE_59: public IP needed for outbound scrape + troubleshooting SSH
  name                = "pip-prometheus-${var.owner}-tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_network_interface" "prometheus_vm" {
  # checkov:skip=CKV_AZURE_119: public IP needed (outbound scrape + troubleshooting SSH), ephemeral VM
  name                = "nic-prometheus-${var.owner}-tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  tags                = local.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.prometheus.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.prometheus_vm.id
  }
}

resource "azurerm_network_interface_security_group_association" "prometheus_vm" {
  network_interface_id      = azurerm_network_interface.prometheus_vm.id
  network_security_group_id = azurerm_network_security_group.prometheus_vm.id
}

# ── SSH key, generated by Terraform ───────────────────────────────────────────
resource "tls_private_key" "prometheus_vm" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# ── Prometheus VM ──────────────────────────────────────────────────────────────
resource "azurerm_linux_virtual_machine" "prometheus" {
  # checkov:skip=CKV_AZURE_149: Trusted Launch not needed for this ephemeral VM
  # checkov:skip=CKV_AZURE_50: antimalware extension not needed for this ephemeral VM
  name                  = "vm-prometheus-${var.owner}-tf"
  resource_group_name   = data.azurerm_resource_group.rg.name
  location              = var.location
  size                  = var.prometheus_vm_size
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.prometheus_vm.id]
  tags                  = local.tags

  identity {
    type = "SystemAssigned"
  }

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.prometheus_vm.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/templates/prometheus-cloud-init.sh.tpl", {
    dce_id       = azurerm_monitor_workspace.amw.default_data_collection_endpoint_id
    dcr_id       = azurerm_monitor_workspace.amw.default_data_collection_rule_id
    app_hostname = data.terraform_remote_state.python.outputs.app_service_hostname
  }))
}

resource "azurerm_role_assignment" "prometheus_publisher" {
  scope                = azurerm_monitor_workspace.amw.default_data_collection_rule_id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_linux_virtual_machine.prometheus.identity[0].principal_id
}

resource "azurerm_role_assignment" "prometheus_dce_reader" {
  scope                = azurerm_monitor_workspace.amw.default_data_collection_endpoint_id
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_linux_virtual_machine.prometheus.identity[0].principal_id
}

resource "azurerm_role_assignment" "prometheus_dcr_reader" {
  scope                = azurerm_monitor_workspace.amw.default_data_collection_rule_id
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_linux_virtual_machine.prometheus.identity[0].principal_id
}

# ── Alert on the app's custom metric (log_erreurs_total) ──────────────────────
# Reuses the "team" Action Group from ../terraform-python/observability.tf via
# terraform_remote_state (action_group_id below) -- no duplicate.

resource "azurerm_monitor_alert_prometheus_rule_group" "alerte_erreurs" {
  name                = "alerte-erreurs-${var.owner}-tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  cluster_name        = azurerm_monitor_workspace.amw.name
  scopes              = [azurerm_monitor_workspace.amw.id]
  tags                = local.tags

  rule {
    enabled    = true
    expression = "log_erreurs_total > 5"
    severity   = 2
    alert      = "alerte-erreurs-${var.owner}"

    action {
      action_group_id = data.terraform_remote_state.python.outputs.action_group_id
    }
  }
}
