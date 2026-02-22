#!/bin/bash
# Add Loki datasource to Grafana

set -euo pipefail

GRAFANA_URL="${1:-http://localhost:3000}"
GRAFANA_USER="${2:-admin}"
GRAFANA_PASS="${3:-admin}"

echo "Adding Loki datasource to Grafana at $GRAFANA_URL..."

# Wait for Grafana to be ready
for i in {1..30}; do
  if curl -sf "$GRAFANA_URL/api/health" >/dev/null; then
    echo "Grafana is ready"
    break
  fi
  echo "Waiting for Grafana to be ready... ($i/30)"
  sleep 2
done

# Add Loki datasource
curl -X POST "$GRAFANA_URL/api/datasources" \
  -H "Content-Type: application/json" \
  -u "$GRAFANA_USER:$GRAFANA_PASS" \
  -d '{
    "name": "Loki",
    "type": "loki",
    "access": "proxy",
    "url": "http://loki:3100",
    "basicAuth": false,
    "isDefault": false,
    "jsonData": {
      "maxLines": 1000
    }
  }' || echo "Loki datasource may already exist"

echo "Grafana datasources updated successfully!"
echo "Access Grafana at: $GRAFANA_URL"
echo "Username: $GRAFANA_USER"
echo "Password: [provided]"
