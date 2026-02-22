#!/bin/bash
# Import dashboard into Grafana

DASHBOARD_FILE="$1"
GRAFANA_URL="${2:-http://localhost:3000}"
GRAFANA_USER="${3:-admin}"
GRAFANA_PASS="${4:-admin}"

if [ ! -f "$DASHBOARD_FILE" ]; then
  echo "ERROR: Dashboard file not found: $DASHBOARD_FILE"
  exit 1
fi

echo "Importing dashboard from $DASHBOARD_FILE..."

# Create the wrapped JSON
PAYLOAD=$(jq -n --argjson dashboard "$(cat $DASHBOARD_FILE)" '{dashboard: $dashboard, overwrite: true}')

# Import to Grafana
RESPONSE=$(curl -s -X POST "$GRAFANA_URL/api/dashboards/db" \
  -H "Content-Type: application/json" \
  -u "$GRAFANA_USER:$GRAFANA_PASS" \
  -d "$PAYLOAD")

echo "$RESPONSE"

if echo "$RESPONSE" | grep -q '"status":"success"'; then
  echo "✓ Dashboard imported successfully!"
  echo "$RESPONSE" | grep -o '"url":"[^"]*"'
else
  echo "✗ Failed to import dashboard"
  exit 1
fi
