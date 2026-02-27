#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────
# setup_grafana_systemd.sh
#
# Installs Grafana as a systemd service on an EC2 instance and
# provisions a Prometheus datasource automatically.
#
# Usage:
#   ./setup_grafana_systemd.sh [ADMIN_PASSWORD]
#
# Default admin password is "admin" if not supplied.
# ────────────────────────────────────────────────────────────────
set -euo pipefail

GRAFANA_VERSION="${GRAFANA_VERSION:-11.2.2}"
ADMIN_PASSWORD="${1:-admin}"

echo "================================================="
echo "  Grafana Systemd Setup"
echo "================================================="

# ── Install Grafana via RPM repository ──────────────────────────
if ! command -v grafana-server &>/dev/null; then
  echo "Adding Grafana YUM repository..."
  sudo tee /etc/yum.repos.d/grafana.repo > /dev/null <<'EOF'
[grafana]
name=Grafana OSS
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

  echo "Installing Grafana ${GRAFANA_VERSION}..."
  sudo yum install -y "grafana-${GRAFANA_VERSION}" 2>/dev/null || sudo yum install -y grafana
  echo "Grafana installed."
else
  echo "Grafana is already installed — skipping."
fi

# ── Configure admin password ────────────────────────────────────
sudo sed -i "s/^;admin_password =.*/admin_password = ${ADMIN_PASSWORD}/" /etc/grafana/grafana.ini 2>/dev/null || true
sudo sed -i "s/^admin_password =.*/admin_password = ${ADMIN_PASSWORD}/" /etc/grafana/grafana.ini 2>/dev/null || true

# ── Provision Prometheus datasource ─────────────────────────────
sudo mkdir -p /etc/grafana/provisioning/datasources
sudo tee /etc/grafana/provisioning/datasources/prometheus.yml > /dev/null <<EOF
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    editable: true
EOF

# ── Provision dashboards directory ──────────────────────────────
sudo mkdir -p /etc/grafana/provisioning/dashboards /var/lib/grafana/dashboards
sudo tee /etc/grafana/provisioning/dashboards/default.yml > /dev/null <<EOF
apiVersion: 1
providers:
  - name: Default
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    editable: true
    updateIntervalSeconds: 30
    options:
      path: /var/lib/grafana/dashboards
      foldersFromFilesStructure: false
EOF

# ── Copy dashboards if they exist next to this script ───────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_DIR="${SCRIPT_DIR}/../observability/grafana"

if [[ -d "$DASHBOARD_DIR" ]]; then
  echo "Copying dashboards from ${DASHBOARD_DIR}..."
  sudo cp "$DASHBOARD_DIR"/*.json /var/lib/grafana/dashboards/ 2>/dev/null || true
  sudo chown -R grafana:grafana /var/lib/grafana/dashboards/
  echo "Dashboards provisioned."
else
  echo "No dashboard directory found at ${DASHBOARD_DIR} — skipping dashboard copy."
  echo "You can manually copy dashboards to /var/lib/grafana/dashboards/ later."
fi

# ── Enable and start ────────────────────────────────────────────
sudo systemctl daemon-reload
sudo systemctl enable grafana-server
sudo systemctl restart grafana-server

echo ""
echo "Grafana status:"
sudo systemctl status grafana-server --no-pager -l || true
echo ""
echo "✓ Grafana is running on port 3000"
echo "  Login:  admin / ${ADMIN_PASSWORD}"
echo "  Config: /etc/grafana/grafana.ini"
echo "  Logs:   journalctl -u grafana-server -f"
echo "  Dashboards: /var/lib/grafana/dashboards/"
