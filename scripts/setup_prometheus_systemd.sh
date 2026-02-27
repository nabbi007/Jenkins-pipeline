#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────
# setup_prometheus_systemd.sh
#
# Installs Prometheus as a systemd service on an EC2 instance.
# Designed for the observability EC2 in this project.
#
# Usage:
#   ./setup_prometheus_systemd.sh [APP_PRIVATE_IP]
#
# If APP_PRIVATE_IP is not supplied, the script tries to read it
# from Terraform outputs or falls back to a placeholder.
# ────────────────────────────────────────────────────────────────
set -euo pipefail

PROMETHEUS_VERSION="${PROMETHEUS_VERSION:-2.54.1}"
PROMETHEUS_USER="prometheus"
APP_PRIVATE_IP="${1:-}"

echo "================================================="
echo "  Prometheus Systemd Setup"
echo "================================================="

# ── Resolve app private IP ──────────────────────────────────────
if [[ -z "$APP_PRIVATE_IP" ]]; then
  # Try to get from instance metadata (if running on the app instance itself)
  APP_PRIVATE_IP=$(curl -sf -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null | \
    xargs -I{} curl -sf -H "X-aws-ec2-metadata-token: {}" \
    http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null) || true

  if [[ -z "$APP_PRIVATE_IP" ]]; then
    echo "WARNING: Could not auto-detect app private IP."
    echo "  Pass it as: $0 <APP_PRIVATE_IP>"
    echo "  Using placeholder 'APP_HOST' — update prometheus.yml before starting."
    APP_PRIVATE_IP="APP_HOST"
  fi
fi
echo "App private IP: $APP_PRIVATE_IP"

# ── Create prometheus user ──────────────────────────────────────
if ! id "$PROMETHEUS_USER" &>/dev/null; then
  sudo useradd --no-create-home --shell /bin/false "$PROMETHEUS_USER"
  echo "Created user: $PROMETHEUS_USER"
fi

# ── Download and install Prometheus ─────────────────────────────
ARCHIVE="prometheus-${PROMETHEUS_VERSION}.linux-amd64"
if [[ ! -f /usr/local/bin/prometheus ]]; then
  echo "Downloading Prometheus v${PROMETHEUS_VERSION}..."
  cd /tmp
  curl -fsSL "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/${ARCHIVE}.tar.gz" -o prometheus.tar.gz
  tar xzf prometheus.tar.gz
  sudo cp "${ARCHIVE}/prometheus" /usr/local/bin/
  sudo cp "${ARCHIVE}/promtool"   /usr/local/bin/
  sudo chown "$PROMETHEUS_USER":"$PROMETHEUS_USER" /usr/local/bin/prometheus /usr/local/bin/promtool
  rm -rf "${ARCHIVE}" prometheus.tar.gz
  echo "Prometheus installed to /usr/local/bin/prometheus"
else
  echo "Prometheus binary already exists — skipping download."
fi

# ── Create directories ──────────────────────────────────────────
sudo mkdir -p /etc/prometheus /var/lib/prometheus
sudo chown -R "$PROMETHEUS_USER":"$PROMETHEUS_USER" /etc/prometheus /var/lib/prometheus

# ── Write prometheus.yml ────────────────────────────────────────
sudo tee /etc/prometheus/prometheus.yml > /dev/null <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - /etc/prometheus/alert_rules.yml

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "backend"
    metrics_path: /metrics
    static_configs:
      - targets: ["${APP_PRIVATE_IP}:3000"]

  - job_name: "node_exporter"
    static_configs:
      - targets:
          - "${APP_PRIVATE_IP}:9100"
          - "localhost:9100"

  - job_name: "redis"
    static_configs:
      - targets: ["${APP_PRIVATE_IP}:9121"]
EOF

# ── Write alert rules ──────────────────────────────────────────
sudo tee /etc/prometheus/alert_rules.yml > /dev/null <<'EOF'
groups:
  - name: backend-alerts
    rules:
      - alert: HighErrorRate
        expr: |
          (
            sum(rate(http_errors_total[5m]))
            /
            sum(rate(http_requests_total[5m]))
          ) * 100 > 5
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Backend error rate is above 5%"
          description: "Error rate has been above 5% for 2 minutes."

      - alert: HighLatencyP95
        expr: |
          histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le)) > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High p95 latency"
          description: "p95 request latency has been above 1s for 5 minutes."

      - alert: BackendDown
        expr: up{job="backend"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Backend is down"
          description: "The backend service has been unreachable for 1 minute."

      - alert: RedisDown
        expr: up{job="redis"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Redis is down"
          description: "Redis exporter has been unreachable for 1 minute."
EOF

sudo chown -R "$PROMETHEUS_USER":"$PROMETHEUS_USER" /etc/prometheus

# ── Create systemd unit ─────────────────────────────────────────
sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus Monitoring
Wants=network-online.target
After=network-online.target

[Service]
User=${PROMETHEUS_USER}
Group=${PROMETHEUS_USER}
Type=simple
ExecStart=/usr/local/bin/prometheus \\
  --config.file=/etc/prometheus/prometheus.yml \\
  --storage.tsdb.path=/var/lib/prometheus \\
  --storage.tsdb.retention.time=30d \\
  --web.listen-address=:9090 \\
  --web.enable-lifecycle
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# ── Enable and start ────────────────────────────────────────────
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl restart prometheus

echo ""
echo "Prometheus status:"
sudo systemctl status prometheus --no-pager -l || true
echo ""
echo "✓ Prometheus is running on port 9090"
echo "  Config: /etc/prometheus/prometheus.yml"
echo "  Data:   /var/lib/prometheus"
echo "  Logs:   journalctl -u prometheus -f"
