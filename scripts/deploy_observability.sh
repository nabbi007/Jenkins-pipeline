#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────
# deploy_observability.sh
#
# One-command setup of the full observability stack on an EC2
# instance: Prometheus (systemd), Grafana (systemd), Node Exporter,
# Loki (Docker), and Promtail (Docker).
#
# Usage:
#   ./deploy_observability.sh <APP_PRIVATE_IP> [GRAFANA_PASSWORD]
#
# Run this ON the observability EC2 instance (via SSH).
# ────────────────────────────────────────────────────────────────
set -euo pipefail

APP_PRIVATE_IP="${1:?Usage: deploy_observability.sh <APP_PRIVATE_IP> [GRAFANA_PASSWORD]}"
GRAFANA_PASSWORD="${2:-admin}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "================================================="
echo "  Full Observability Stack Deployment"
echo "================================================="
echo "  App private IP:   $APP_PRIVATE_IP"
echo "  Grafana password: $GRAFANA_PASSWORD"
echo "================================================="
echo ""

# ── 1. Install Docker (if not present) ──────────────────────────
if ! command -v docker &>/dev/null; then
  echo "Installing Docker..."
  sudo yum install -y docker
  sudo systemctl enable docker
  sudo systemctl start docker
  sudo usermod -aG docker "$(whoami)"
  echo "Docker installed and started."
else
  echo "Docker already installed."
fi

# ── 2. Setup Prometheus (systemd) ───────────────────────────────
echo ""
echo "--- Setting up Prometheus ---"
if [[ -f "${SCRIPT_DIR}/setup_prometheus_systemd.sh" ]]; then
  bash "${SCRIPT_DIR}/setup_prometheus_systemd.sh" "$APP_PRIVATE_IP"
else
  echo "ERROR: setup_prometheus_systemd.sh not found in ${SCRIPT_DIR}"
  exit 1
fi

# ── 3. Setup Grafana (systemd) ──────────────────────────────────
echo ""
echo "--- Setting up Grafana ---"
if [[ -f "${SCRIPT_DIR}/setup_grafana_systemd.sh" ]]; then
  bash "${SCRIPT_DIR}/setup_grafana_systemd.sh" "$GRAFANA_PASSWORD"
else
  echo "ERROR: setup_grafana_systemd.sh not found in ${SCRIPT_DIR}"
  exit 1
fi

# ── 4. Node Exporter (Docker — for obs host metrics) ────────────
echo ""
echo "--- Setting up Node Exporter ---"
if docker ps --format '{{.Names}}' | grep -q '^node-exporter$'; then
  echo "Node Exporter already running."
else
  docker rm -f node-exporter 2>/dev/null || true
  docker run -d \
    --name node-exporter \
    --restart unless-stopped \
    -p 9100:9100 \
    --net host \
    prom/node-exporter:latest
  echo "✓ Node Exporter running on port 9100"
fi

# ── 5. Loki (Docker — log aggregation) ──────────────────────────
echo ""
echo "--- Setting up Loki ---"
if docker ps --format '{{.Names}}' | grep -q '^loki$'; then
  echo "Loki already running."
else
  docker rm -f loki 2>/dev/null || true
  sudo mkdir -p /opt/loki
  docker run -d \
    --name loki \
    --restart unless-stopped \
    -p 3100:3100 \
    -v /opt/loki:/loki \
    grafana/loki:2.9.2 \
    -config.file=/etc/loki/local-config.yaml
  echo "✓ Loki running on port 3100"
fi

# ── 6. Promtail (Docker — ships logs to Loki) ───────────────────
echo ""
echo "--- Setting up Promtail ---"
if docker ps --format '{{.Names}}' | grep -q '^promtail$'; then
  echo "Promtail already running."
else
  docker rm -f promtail 2>/dev/null || true

  sudo mkdir -p /opt/promtail
  sudo tee /opt/promtail/config.yml > /dev/null <<EOF
server:
  http_listen_port: 9080

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://localhost:3100/loki/api/v1/push

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*.log
EOF

  docker run -d \
    --name promtail \
    --restart unless-stopped \
    -p 9080:9080 \
    --net host \
    -v /opt/promtail/config.yml:/etc/promtail/config.yml:ro \
    -v /var/log:/var/log:ro \
    grafana/promtail:2.9.2 \
    -config.file=/etc/promtail/config.yml
  echo "✓ Promtail running on port 9080"
fi

# ── 7. Add Loki datasource to Grafana ───────────────────────────
echo ""
echo "--- Adding Loki datasource to Grafana ---"
sleep 5  # Give Grafana a moment to start
curl -sf -X POST "http://localhost:3000/api/datasources" \
  -H "Content-Type: application/json" \
  -u "admin:${GRAFANA_PASSWORD}" \
  -d '{
    "name": "Loki",
    "type": "loki",
    "access": "proxy",
    "url": "http://localhost:3100",
    "isDefault": false
  }' 2>/dev/null && echo "✓ Loki datasource added to Grafana" || echo "  Loki datasource may already exist — skipping."

echo ""
echo "================================================="
echo "  Observability Stack Deployed Successfully!"
echo "================================================="
echo ""
echo "  Prometheus: http://$(curl -sf http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo '<obs-ip>'):9090"
echo "  Grafana:    http://$(curl -sf http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo '<obs-ip>'):3000"
echo "    Login:    admin / ${GRAFANA_PASSWORD}"
echo "  Loki:       http://localhost:3100 (internal)"
echo ""
echo "  To check status:"
echo "    systemctl status prometheus"
echo "    systemctl status grafana-server"
echo "    docker ps"
echo ""
