#!/bin/bash
# Install and run node-exporter as a native systemd service

set -euo pipefail

NODE_EXPORTER_VERSION="1.8.2"
ARCH="linux-amd64"

echo "Installing Node Exporter ${NODE_EXPORTER_VERSION} as a systemd service..."

# Stop and remove Docker version if it exists
if docker ps -a | grep -q node-exporter; then
  echo "Removing existing Docker container..."
  docker stop node-exporter 2>/dev/null || true
  docker rm node-exporter 2>/dev/null || true
fi

# Check if already installed
if systemctl is-active --quiet node_exporter; then
  echo "Node exporter service is already running"
  systemctl status node_exporter --no-pager
  exit 0
fi

# Create node_exporter user if not exists
if ! id -u node_exporter >/dev/null 2>&1; then
  echo "Creating node_exporter user..."
  useradd --no-create-home --shell /bin/false node_exporter
fi

# Download and install binary
cd /tmp
echo "Downloading Node Exporter ${NODE_EXPORTER_VERSION}..."
curl -fsSL "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.${ARCH}.tar.gz" \
  -o node_exporter.tar.gz

echo "Extracting and installing..."
tar -xzf node_exporter.tar.gz
cp node_exporter-${NODE_EXPORTER_VERSION}.${ARCH}/node_exporter /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter
chmod +x /usr/local/bin/node_exporter

# Clean up
rm -rf node_exporter.tar.gz node_exporter-${NODE_EXPORTER_VERSION}.${ARCH}

# Create systemd service file
cat >/etc/systemd/system/node_exporter.service <<'EOF'
[Unit]
Description=Node Exporter
Documentation=https://github.com/prometheus/node_exporter
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=node_exporter
Group=node_exporter
ExecStart=/usr/local/bin/node_exporter \
  --collector.filesystem.mount-points-exclude='^/(dev|proc|sys|var/lib/docker/.+|var/lib/kubelet/.+)($|/)' \
  --collector.netclass.ignored-devices='^(veth.*)$'
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start service
echo "Starting node_exporter service..."
systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

# Verify
sleep 2
if systemctl is-active --quiet node_exporter; then
  echo "Node Exporter installed and running successfully!"
  echo ""
  systemctl status node_exporter --no-pager -l
  echo ""
  echo "Metrics available at: http://localhost:9100/metrics"
else
  echo "Failed to start node_exporter service"
  journalctl -u node_exporter --no-pager -n 20
  exit 1
fi
