#!/bin/bash
# Install Prometheus as a native systemd service

set -euo pipefail

PROMETHEUS_VERSION="2.54.1"
PROMETHEUS_USER="prometheus"
PROMETHEUS_DIR="/opt/prometheus"
CONFIG_DIR="/etc/prometheus"
DATA_DIR="/var/lib/prometheus"

echo "Installing Prometheus v${PROMETHEUS_VERSION} as systemd service..."

# Stop and remove Docker container if exists
if docker ps -a --format '{{.Names}}' | grep -q '^prometheus$'; then
    echo "Removing existing Prometheus container..."
    docker stop prometheus 2>/dev/null || true
    docker rm prometheus 2>/dev/null || true
fi

# Create prometheus user
if ! id "$PROMETHEUS_USER" &>/dev/null; then
    echo "Creating $PROMETHEUS_USER user..."
    sudo useradd --no-create-home --shell /bin/false $PROMETHEUS_USER
fi

# Create directories
echo "Creating directories..."
sudo mkdir -p $PROMETHEUS_DIR $CONFIG_DIR $DATA_DIR
sudo mkdir -p $CONFIG_DIR/rules

# Download and install Prometheus
echo "Downloading Prometheus..."
cd /tmp
wget -q https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
tar xzf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz

echo "Installing Prometheus binaries..."
sudo cp prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus /usr/local/bin/
sudo cp prometheus-${PROMETHEUS_VERSION}.linux-amd64/promtool /usr/local/bin/
sudo chmod +x /usr/local/bin/prometheus /usr/local/bin/promtool

# Copy console files
sudo cp -r prometheus-${PROMETHEUS_VERSION}.linux-amd64/consoles $CONFIG_DIR/
sudo cp -r prometheus-${PROMETHEUS_VERSION}.linux-amd64/console_libraries $CONFIG_DIR/

# Clean up
rm -rf prometheus-${PROMETHEUS_VERSION}.linux-amd64*

# Create/update Prometheus configuration
echo "Creating Prometheus configuration..."
sudo tee $CONFIG_DIR/prometheus.yml > /dev/null << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: []

rule_files:
  # - "rules/*.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'backend'
    static_configs:
      - targets: ['172.31.3.138:3000']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['172.31.3.138:9100', 'localhost:9100']

  - job_name: 'redis'
    static_configs:
      - targets: ['172.31.3.138:9121']
EOF

# Set ownership
echo "Setting permissions..."
sudo chown -R $PROMETHEUS_USER:$PROMETHEUS_USER $PROMETHEUS_DIR $CONFIG_DIR $DATA_DIR

# Create systemd service file
echo "Creating systemd service..."
sudo tee /etc/systemd/system/prometheus.service > /dev/null << EOF
[Unit]
Description=Prometheus Time Series Database
Documentation=https://prometheus.io/docs/introduction/overview/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$PROMETHEUS_USER
Group=$PROMETHEUS_USER
ExecReload=/bin/kill -HUP \$MAINPID
ExecStart=/usr/local/bin/prometheus \\
  --config.file=$CONFIG_DIR/prometheus.yml \\
  --storage.tsdb.path=$DATA_DIR \\
  --storage.tsdb.retention.time=15d \\
  --web.console.templates=$CONFIG_DIR/consoles \\
  --web.console.libraries=$CONFIG_DIR/console_libraries \\
  --web.listen-address=0.0.0.0:9090 \\
  --web.enable-lifecycle

SyslogIdentifier=prometheus
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start service
echo "Starting Prometheus service..."
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl restart prometheus

# Wait for startup
sleep 5

# Verify
if systemctl is-active --quiet prometheus; then
    echo "✓ Prometheus service is running"
    echo "✓ Prometheus available at: http://localhost:9090"
    echo "✓ Config file: $CONFIG_DIR/prometheus.yml"
    echo "✓ Data directory: $DATA_DIR"
else
    echo "✗ Prometheus service failed to start"
    sudo systemctl status prometheus --no-pager
    exit 1
fi
