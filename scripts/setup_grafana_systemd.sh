#!/bin/bash
# Install Grafana as a native systemd service

set -euo pipefail

GRAFANA_VERSION="11.2.2"
GRAFANA_USER="grafana"
GRAFANA_DIR="/opt/grafana"
CONFIG_DIR="/etc/grafana"
DATA_DIR="/var/lib/grafana"
LOG_DIR="/var/log/grafana"

echo "Installing Grafana v${GRAFANA_VERSION} as systemd service..."

# Stop and remove Docker container if exists
if docker ps -a --format '{{.Names}}' | grep -q '^grafana$'; then
    echo "Removing existing Grafana container..."
    docker stop grafana 2>/dev/null || true
    docker rm grafana 2>/dev/null || true
fi

# Create grafana user
if ! id "$GRAFANA_USER" &>/dev/null; then
    echo "Creating $GRAFANA_USER user..."
    sudo useradd --no-create-home --shell /bin/false $GRAFANA_USER
fi

# Create directories
echo "Creating directories..."
sudo mkdir -p $GRAFANA_DIR $CONFIG_DIR $DATA_DIR $LOG_DIR
sudo mkdir -p $CONFIG_DIR/provisioning/datasources
sudo mkdir -p $CONFIG_DIR/provisioning/dashboards
sudo mkdir -p $DATA_DIR/dashboards

# Download and install Grafana
echo "Downloading Grafana..."
cd /tmp
wget -q https://dl.grafana.com/oss/release/grafana-${GRAFANA_VERSION}.linux-amd64.tar.gz
tar xzf grafana-${GRAFANA_VERSION}.linux-amd64.tar.gz

echo "Installing Grafana..."
sudo cp -r grafana-v${GRAFANA_VERSION}/* $GRAFANA_DIR/

# Clean up
rm -rf grafana-*

# Create Grafana configuration
echo "Creating Grafana configuration..."
sudo tee $CONFIG_DIR/grafana.ini > /dev/null << 'EOF'
[paths]
data = /var/lib/grafana
logs = /var/log/grafana
plugins = /var/lib/grafana/plugins
provisioning = /etc/grafana/provisioning

[server]
protocol = http
http_port = 3000
domain = localhost
root_url = %(protocol)s://%(domain)s:%(http_port)s/

[database]
type = sqlite3
path = grafana.db

[security]
admin_user = admin
admin_password = admin

[users]
allow_sign_up = false

[auth.anonymous]
enabled = false

[log]
mode = console file
level = info

[log.console]
level = info

[log.file]
level = info
log_rotate = true
max_lines = 1000000
max_size_shift = 28
daily_rotate = true
max_days = 7
EOF

# Create datasource provisioning
echo "Configuring datasources..."
sudo tee $CONFIG_DIR/provisioning/datasources/datasources.yml > /dev/null << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    uid: prometheus
    jsonData:
      timeInterval: 15s
      httpMethod: POST
    editable: true

  - name: Loki
    type: loki
    access: proxy
    url: http://localhost:3100
    isDefault: false
    uid: loki
    jsonData:
      maxLines: 1000
    editable: true
EOF

# Create dashboard provisioning
echo "Configuring dashboard provisioning..."
sudo tee $CONFIG_DIR/provisioning/dashboards/dashboards.yml > /dev/null << 'EOF'
apiVersion: 1

providers:
  - name: 'Default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
      foldersFromFilesStructure: true
EOF

# Set ownership
echo "Setting permissions..."
sudo chown -R $GRAFANA_USER:$GRAFANA_USER $GRAFANA_DIR $CONFIG_DIR $DATA_DIR $LOG_DIR

# Create systemd service file
echo "Creating systemd service..."
sudo tee /etc/systemd/system/grafana.service > /dev/null << EOF
[Unit]
Description=Grafana
Documentation=https://grafana.com/docs/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$GRAFANA_USER
Group=$GRAFANA_USER
WorkingDirectory=$GRAFANA_DIR
ExecStart=$GRAFANA_DIR/bin/grafana-server \\
  --config=$CONFIG_DIR/grafana.ini \\
  --homepath=$GRAFANA_DIR

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start service
echo "Starting Grafana service..."
sudo systemctl daemon-reload
sudo systemctl enable grafana
sudo systemctl restart grafana

# Wait for startup
sleep 8

# Verify
if systemctl is-active --quiet grafana; then
    echo "✓ Grafana service is running"
    echo "✓ Grafana available at: http://localhost:3000"
    echo "✓ Username: admin"
    echo "✓ Password: admin"
    echo "✓ Config file: $CONFIG_DIR/grafana.ini"
    echo "✓ Data directory: $DATA_DIR"
    echo "✓ Dashboard directory: $DATA_DIR/dashboards"
else
    echo "✗ Grafana service failed to start"
    sudo systemctl status grafana --no-pager
    exit 1
fi
