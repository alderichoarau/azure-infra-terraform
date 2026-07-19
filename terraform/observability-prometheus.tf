# Observability stack, part 2: Prometheus managé (Azure Monitor managed service for
# Prometheus) + Grafana managé, en complément d'observability.tf (Log Analytics +
# Application Insights + Availability Tests + alertes, qui reste inchangé).
#
# Pourquoi un fichier séparé plutôt qu'une extension d'observability.tf : ce sont deux
# signaux différents (traces/requêtes vs métriques custom exposées par l'app en /metrics)
# et deux stades pédagogiques différents du TP observabilité — garder le diff propre et
# le fichier existant intact.
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

# Le provider "tls" est déclaré dans providers.tf (un seul bloc required_providers
# autorisé par module — Terraform refuse d'en avoir un second ici, même pour un
# provider différent).

# ── Azure Monitor Workspace (Prometheus managé) ───────────────────────────────
# Crée automatiquement, en arrière-plan, un Data Collection Endpoint et un Data
# Collection Rule dédiés (exposés ci-dessous via default_data_collection_*_id) —
# on ne les crée pas nous-mêmes.

resource "azurerm_monitor_workspace" "amw" {
  name                = "amw-${var.owner}-tf"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  tags                = local.tags
}

# ── Grafana managé ────────────────────────────────────────────────────────────

resource "azurerm_dashboard_grafana" "grafana" {
  # Azure Managed Grafana impose un nom de 2 à 23 caractères (lettres/chiffres/tirets) —
  # bien plus court que les autres ressources de ce fichier. "grafana-${owner}-tf" dépasse
  # cette limite dès que owner fait plus de ~11 caractères ; on retire les tirets et le
  # suffixe "-tf" puis on tronque, pour rester dans la limite quelle que soit la longueur
  # de var.owner (garanti alphanumérique, donc jamais de tiret final après troncature).
  name                  = substr("grafana${replace(var.owner, "-", "")}", 0, 23)
  resource_group_name   = data.azurerm_resource_group.rg.name
  location              = var.location
  grafana_major_version = "12" # les versions valides évoluent régulièrement côté Azure (11→12→13 constaté en quelques jours sur ce repo) ; confirmé par l'erreur Azure elle-même à l'apply, plus fiable que la doc — si ça re-casse un jour, le message d'erreur donnera les valeurs valides du moment
  tags                  = local.tags

  identity {
    type = "SystemAssigned"
  }
}

# Sans ce rôle, la source de données Azure Monitor dans Grafana ne remonte aucune donnée
# (ni les logs App Insights, ni les métriques Prometheus managé).
resource "azurerm_role_assignment" "grafana_monitoring_reader" {
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_dashboard_grafana.grafana.identity[0].principal_id
}

# ── Réseau dédié à la VM Prometheus ────────────────────────────────────────────
# Subnet dédié plutôt que subnet-backend partagé (module.network) : ce dernier a
# son propre NSG avec des blocs security_rule INLINE (Allow-From-Frontend,
# Deny-All-Inbound, Deny-All-Outbound), et AzureRM déconseille explicitement de
# mélanger security_rule inline sur azurerm_network_security_group et des
# azurerm_network_security_rule autonomes sur le même NSG : les deux se battent
# pour l'état de la liste de règles à chaque apply (l'un la déclare de façon
# exhaustive, l'autre y ajoute "hors module"), ce qui a produit en pratique un
# comportement instable — une des deux règles ajoutées disparaissait à chaque
# apply, jamais la même. Un subnet dédié avec uniquement notre propre NSG
# (jamais partagé avec une autre resource Terraform) élimine le conflit : un
# seul propriétaire de la liste de règles, point.
#
# 10.0.3.0/24 : libre dans l'address space du VNet (10.0.0.0/16), à côté de
# subnet-frontend (10.0.1.0/24) et subnet-backend (10.0.2.0/24, cf. defaults du
# module network).

resource "azurerm_subnet" "prometheus" {
  name                 = "subnet-prometheus"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = module.network.vnet_name
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

  # Pas de règle Outbound explicite : les règles par défaut d'Azure
  # (AllowInternetOutBound, priorité 65001) s'appliquent donc telles quelles —
  # c'est ce qu'on veut, la VM a besoin d'Internet sortant (apt, binaire
  # Prometheus, ARM pour le DCE/DCR, scrape HTTPS de l'App Service, remote_write).
  # Un Deny-All-Outbound explicite ici demanderait de ré-ouvrir 80/443 nous-mêmes,
  # pour un gain de sécurité marginal sur une VM de TP éphémère.
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
  # checkov:skip=CKV_AZURE_119: IP publique nécessaire (scrape sortant vers l'App Service +
  # SSH de dépannage) sur ce TP éphémère ; à revoir (Bastion / NAT Gateway) pour un usage réel
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
# Volontairement pas de file("~/.ssh/id_rsa.pub") : ce repo tourne aussi en CI
# (automation_only), où aucune clé locale n'existe sur le runner. La clé privée
# sort en output sensible, à récupérer avec `terraform output -raw prometheus_vm_ssh_private_key`
# si un dépannage manuel est nécessaire.

resource "tls_private_key" "prometheus_vm" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# ── VM Prometheus ──────────────────────────────────────────────────────────────
# Le script custom_data (cloud-init) est auto-suffisant : il installe Prometheus
# et Azure CLI, s'authentifie via l'identité managée de la VM (az login --identity),
# résout lui-même l'endpoint d'ingestion et l'immutable ID du DCR auto-créé, écrit
# prometheus.yml et démarre le service — un seul `terraform apply`, aucune étape
# manuelle az cli côté apprenant.

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
    app_hostname = module.app_service.default_hostname # App Service déployé via le module registry (app-service.tf), pas une resource locale
  }))
}

resource "azurerm_role_assignment" "prometheus_publisher" {
  scope                = azurerm_monitor_workspace.amw.default_data_collection_rule_id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_linux_virtual_machine.prometheus.identity[0].principal_id
}

# ── Alerte sur la métrique custom exposée par l'app (log_erreurs_total) ───────
# Réutilise l'Action Group "team" défini dans observability.tf — pas de doublon.

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
    alert      = "alerte-erreurs-${var.owner}" # obligatoire : une rule est soit une "alert" (alerting rule), soit un "record" (recording rule) — jamais les deux, jamais ni l'un ni l'autre

    action {
      action_group_id = azurerm_monitor_action_group.team.id
    }
  }
}
