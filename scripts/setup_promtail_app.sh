#!/bin/bash
# Deploy Promtail on app EC2 to ship logs to Loki

set -euo pipefail

LOKI_URL="${1:?Usage: $0 <LOKI_URL> (e.g., http://108.130.163.21:3100)}"

echo "Setting up Promtail to ship logs to $LOKI_URL..."

mkdir -p /opt/promtail

# Promtail config
cat >/opt/promtail/promtail-config.yml <<EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/promtail-positions.yaml

clients:
  - url: ${LOKI_URL}/loki/api/v1/push

scrape_configs:
  # System logs
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: syslog
          host: app-host
          __path__: /var/log/messages

  # Docker container logs (backend, frontend, redis)
  - job_name: docker_containers
    static_configs:
      - targets:
          - localhost
        labels:
          job: docker
          host: app-host
          __path__: /var/lib/docker/containers/*/*-json.log
    pipeline_stages:
      - json:
          expressions:
            log: log
            stream: stream
            attrs: attrs
      - json:
          expressions:
            container_name: attrs.name
          source: attrs
      - labels:
          container_name:
          stream:
      - output:
          source: log
EOF

# Stop existing Promtail if running
docker stop promtail 2>/dev/null || true
docker rm promtail 2>/dev/null || true

# Start Promtail
echo "Starting Promtail..."
docker run -d \
  --name promtail \
  --restart unless-stopped \
  -p 9080:9080 \
  -v /opt/promtail/promtail-config.yml:/etc/promtail/config.yml:ro \
  -v /var/log:/var/log:ro \
  -v /var/lib/docker/containers:/var/lib/docker/containers:ro \
  -v /tmp:/tmp \
  grafana/promtail:3.0.0 \
  -config.file=/etc/promtail/config.yml

echo "Promtail deployed successfully!"
echo "Promtail metrics: http://localhost:9080/metrics"
echo "Shipping logs to: $LOKI_URL"
