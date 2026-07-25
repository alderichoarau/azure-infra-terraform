#!/bin/bash
# cloud-init pour la VM Prometheus (voir observability-prometheus.tf).
# Auto-suffisant : installe Prometheus + Azure CLI, s'authentifie via l'identité
# managée de la VM, résout l'endpoint d'ingestion et l'immutable ID du Data
# Collection Rule auto-créé par l'Azure Monitor Workspace, puis démarre le scrape
# + remote_write. Aucune étape manuelle après le `terraform apply`.
set -e

apt-get update
apt-get install -y wget curl

# Azure CLI (nécessaire pour résoudre l'endpoint remote_write via l'identité managée)
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Binaire Prometheus — 3.12.0, PAS 2.53.0 : l'authentification remote_write par identité
# managée SYSTÈME (notre cas, VM avec identity { type = "SystemAssigned" } et
# managed_identity.client_id = "" dans prometheus.yml) nécessite Prometheus 3.50+ d'après
# la doc Microsoft (https://learn.microsoft.com/azure/azure-monitor/metrics/prometheus-remote-write,
# table "Supported versions") — 2.53.0 ne supporte que l'identité managée UTILISATEUR
# (client_id non vide) et plante au démarrage avec "must provide an Azure Managed Identity
# client_id in the Azure AD config". Confirmé en conditions réelles sur cette VM.
cd /tmp
wget -q https://github.com/prometheus/prometheus/releases/download/v3.12.0/prometheus-3.12.0.linux-amd64.tar.gz
tar xzf prometheus-3.12.0.linux-amd64.tar.gz
cp prometheus-3.12.0.linux-amd64/prometheus /usr/local/bin/
mkdir -p /etc/prometheus /var/lib/prometheus

# L'attribution du rôle Monitoring Metrics Publisher peut prendre jusqu'à 30 min
# à se propager après le terraform apply — quelques tentatives suffisent en
# pratique pour le login (l'identité managée elle-même est dispo dès le boot).
for i in $(seq 1 10); do
  az login --identity && break
  echo "En attente de l'identité managée... (tentative $i/10)"
  sleep 15
done

# Syntaxe CLI vérifiée manuellement sur la VM (az cli 2.88.0) : le groupe est
# "data-collection endpoint"/"data-collection rule" (mots séparés), pas
# "data-collection-endpoint"/"data-collection-rule" (un seul mot à tiret) —
# l'ancienne syntaxe (extension monitor-control-service, avant fusion dans le
# coeur d'az cli) renvoie "not recognized by the system".
DCE_ENDPOINT=$(az monitor data-collection endpoint show --ids "${dce_id}" --query metricsIngestionEndpoint -o tsv)
DCR_IMMUTABLE_ID=$(az monitor data-collection rule show --ids "${dcr_id}" --query immutableId -o tsv)

cat > /etc/prometheus/prometheus.yml <<PROMCONF
global:
  scrape_interval: 30s

scrape_configs:
  - job_name: 'log-analyser-app'
    scheme: https
    static_configs:
      - targets: ['${app_hostname}']

remote_write:
  - url: "$${DCE_ENDPOINT}/dataCollectionRules/$${DCR_IMMUTABLE_ID}/streams/Microsoft-PrometheusMetrics/api/v1/write?api-version=2023-04-24"
    azuread:
      cloud: 'AzurePublic'
      managed_identity:
        client_id: ""
PROMCONF

cat > /etc/systemd/system/prometheus.service <<UNIT
[Unit]
Description=Prometheus
After=network.target

[Service]
User=root
ExecStart=/usr/local/bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/var/lib/prometheus
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus
