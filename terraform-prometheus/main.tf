# ──────────────────────────────────────────────────────────────────────────────
# Observability stack, part 2: Prometheus managé (Azure Monitor managed service for
# Prometheus) + Grafana managé, en complément d'observability.tf (../terraform-python,
# Log Analytics + Application Insights + Availability Tests + alertes).
#
# Extrait dans son propre répertoire/state (voir backend.tf) précisément parce que
# ce sont les ressources les plus chères du repo, pensées pour tourner 24/7 une fois
# activées -- avant cette extraction, tout vivait dans ../terraform derrière un
# count = var.enable_prometheus_stack ? 1 : 0 sur chaque resource, pour éviter de
# les recréer à chaque cycle destroy/apply pendant qu'on itérait sur la piste
# Java/Angular. Un répertoire séparé rend ce même objectif structurel plutôt
# qu'conditionnel : appliquer/détruire CE répertoire est maintenant le toggle.
#
# Pourquoi un fichier séparé d'observability.tf à l'origine, raison inchangée :
# ce sont deux signaux différents (traces/requêtes vs métriques custom exposées
# par l'app en /metrics) et deux stades pédagogiques différents du TP observabilité.
#
# Prérequis opérationnel non couvert par ce fichier — et plus large qu'il n'y paraît :
# azurerm_monitor_workspace crée son Data Collection Rule par défaut dans un resource
# group managé séparé, généré par Azure (ex: "MA_amw-<owner>-tf_<region>_managed"),
# PAS dans data.azurerm_resource_group.rg. "User Access Administrator" donné seulement
# sur le RG de l'apprenant ne couvre donc pas ce RG managé (il n'existe même pas encore
# au moment où on donnerait ce droit). Il faut ce rôle (ou "Role Based Access Control
# Administrator", plus restreint et suffisant ici) au niveau de l'ABONNEMENT pour le
# principal qui fait terraform apply — sans ça, azurerm_role_assignment.prometheus_publisher
# échoue en 403 AuthorizationFailed, même si Contributor + UAA sont bien présents sur le RG.
#
# Authentification remote_write : validée par Microsoft pour VM/VMSS et AKS avec identité
# managée — pas (encore) pour Container Apps, d'où le choix d'une VM ici plutôt qu'un
# conteneur. Voir https://learn.microsoft.com/azure/azure-monitor/metrics/prometheus-remote-write
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

# ── Azure Monitor Workspace (Prometheus managé) ───────────────────────────────

resource "azurerm_monitor_workspace" "amw" {
  name                = "amw-${var.owner}-tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  tags                = local.tags
}

# ── Grafana managé ────────────────────────────────────────────────────────────

resource "azurerm_dashboard_grafana" "grafana" {
  # Azure Managed Grafana impose un nom de 2 à 23 caractères (lettres/chiffres/tirets).
  name                  = substr("grafana${replace(var.owner, "-", "")}", 0, 23)
  resource_group_name   = data.azurerm_resource_group.rg.name
  location              = var.location
  grafana_major_version = "12" # les versions valides évoluent régulièrement côté Azure -- si ça casse, le message d'erreur Azure donne les valeurs valides du moment
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

# ── Réseau dédié à la VM Prometheus ────────────────────────────────────────────
# Subnet dédié plutôt que subnet-backend (module.network, ../terraform-core) : ce
# dernier a son propre NSG avec des security_rule inline, et AzureRM déconseille
# de mélanger ça avec des azurerm_network_security_rule autonomes sur le même
# NSG (comportement instable constaté en pratique). Un subnet + NSG dédiés,
# jamais partagés, élimine le conflit.
#
# 10.0.3.0/24 : libre dans l'address space du VNet (10.0.0.0/16, ../terraform-core),
# à côté de subnet-frontend (10.0.1.0/24) et subnet-backend (10.0.2.0/24).

resource "azurerm_subnet" "prometheus" {
  name                 = "subnet-prometheus"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = data.terraform_remote_state.core.outputs.vnet_name
  address_prefixes     = ["10.0.3.0/24"]
}

resource "azurerm_network_security_group" "prometheus_vm" {
  # checkov:skip=CKV_AZURE_10: SSH ouvert pour les besoins du TP (dépannage) — à restreindre
  # à l'IP de la salle en usage réel, cf. var.trainer_ip_cidr
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

  # Pas de règle Outbound explicite : les règles par défaut d'Azure suffisent
  # (la VM a besoin d'Internet sortant -- apt, binaire Prometheus, ARM, scrape,
  # remote_write).
}

resource "azurerm_subnet_network_security_group_association" "prometheus" {
  subnet_id                 = azurerm_subnet.prometheus.id
  network_security_group_id = azurerm_network_security_group.prometheus_vm.id
}

resource "azurerm_public_ip" "prometheus_vm" {
  # checkov:skip=CKV_AZURE_59: IP publique nécessaire pour le scrape sortant + SSH de dépannage sur ce TP
  name                = "pip-prometheus-${var.owner}-tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_network_interface" "prometheus_vm" {
  # checkov:skip=CKV_AZURE_119: IP publique nécessaire (scrape sortant + SSH de dépannage) sur ce TP éphémère
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

# ── Clé SSH générée par Terraform ─────────────────────────────────────────────
resource "tls_private_key" "prometheus_vm" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# ── VM Prometheus ──────────────────────────────────────────────────────────────
resource "azurerm_linux_virtual_machine" "prometheus" {
  # checkov:skip=CKV_AZURE_149: pas de Trusted Launch nécessaire pour cette VM de TP éphémère
  # checkov:skip=CKV_AZURE_50: pas d'extension antimalware nécessaire pour cette VM de TP éphémère
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

# ── Alerte sur la métrique custom exposée par l'app (log_erreurs_total) ───────
# Réutilise l'Action Group "team" de ../terraform-python/observability.tf via
# terraform_remote_state (action_group_id ci-dessous) -- pas de doublon.

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
