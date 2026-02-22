#!/bin/bash
# Deploy Loki + Promtail on observability EC2 for log aggregation

set -euo pipefail

APP_HOST="${1:-localhost}"

echo "Setting up Loki stack to collect logs from $APP_HOST..."

# Create config directories
mkdir -p /opt/observability/loki
mkdir -p /opt/observability/promtail

# Loki config
cat >/opt/observability/loki/loki-config.yml <<'EOF'
auth_enabled: false

server:
  http_listen_port: 3100

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

limits_config:
  retention_period: 168h  # 7 days

compactor:
  working_directory: /loki/compactor
  compaction_interval: 10m
  retention_enabled: true
  retention_delete_delay: 2h
  retention_delete_worker_count: 150
  delete_request_store: filesystem
EOF

# Promtail config for app EC2 (remote scraping via Docker API)
cat >/opt/observability/promtail/promtail-config.yml <<EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  # Local observability host logs
  - job_name: observability_system
    static_configs:
      - targets:
          - localhost
        labels:
          job: syslog
          host: observability
          __path__: /var/log/messages

  # Backend container logs via Docker API (requires mounting docker socket)
  - job_name: backend_app
    docker_sd_configs:
      - host: tcp://${APP_HOST}:2375
        refresh_interval: 15s
    relabel_configs:
      - source_labels: ['__meta_docker_container_name']
        regex: '/backend'
        action: keep
      - source_labels: ['__meta_docker_container_name']
        target_label: container
      - source_labels: ['__meta_docker_container_log_stream']
        target_label: stream

  # Frontend container logs
  - job_name: frontend_app
    docker_sd_configs:
      - host: tcp://${APP_HOST}:2375
        refresh_interval: 15s
    relabel_configs:
      - source_labels: ['__meta_docker_container_name']
        regex: '/frontend'
        action: keep
      - source_labels: ['__meta_docker_container_name']
        target_label: container
      - source_labels: ['__meta_docker_container_log_stream']
        target_label: stream
EOF

# Check if observability network exists
docker network inspect obs-net >/dev/null 2>&1 || docker network create obs-net

# Stop existing containers if running
docker stop loki promtail 2>/dev/null || true
docker rm loki promtail 2>/dev/null || true

# Start Loki
echo "Starting Loki..."
docker run -d \
  --name loki \
  --restart unless-stopped \
  --network obs-net \
  -p 3100:3100 \
  -v /opt/observability/loki:/loki \
  -v /opt/observability/loki/loki-config.yml:/etc/loki/loki-config.yml:ro \
  grafana/loki:3.0.0 \
  -config.file=/etc/loki/loki-config.yml

# Start Promtail
echo "Starting Promtail..."
docker run -d \
  --name promtail \
  --restart unless-stopped \
  --network obs-net \
  -p 9080:9080 \
  -v /opt/observability/promtail/promtail-config.yml:/etc/promtail/promtail-config.yml:ro \
  -v /var/log:/var/log:ro \
  grafana/promtail:3.0.0 \
  -config.file=/etc/promtail/promtail-config.yml

echo "Loki stack deployed successfully!"
echo "Loki API: http://localhost:3100"
echo "Promtail: http://localhost:9080"
