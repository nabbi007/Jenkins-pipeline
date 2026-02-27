#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────
# import_dashboards.sh
#
# Imports Grafana dashboards from the observability/grafana/
# directory via the Grafana HTTP API.
#
# Usage:
#   ./import_dashboards.sh <GRAFANA_URL> [ADMIN_PASSWORD]
#
# Example:
#   ./import_dashboards.sh http://108.130.163.21:3000 admin
# ────────────────────────────────────────────────────────────────
set -euo pipefail

GRAFANA_URL="${1:?Usage: import_dashboards.sh <GRAFANA_URL> [ADMIN_PASSWORD]}"
GRAFANA_URL="${GRAFANA_URL%/}"  # strip trailing slash
ADMIN_PASSWORD="${2:-admin}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_DIR="${SCRIPT_DIR}/../observability/grafana"

echo "================================================="
echo "  Grafana Dashboard Import"
echo "================================================="
echo "  Grafana URL: ${GRAFANA_URL}"
echo "  Dashboard dir: ${DASHBOARD_DIR}"
echo ""

if [[ ! -d "$DASHBOARD_DIR" ]]; then
  echo "ERROR: Dashboard directory not found at ${DASHBOARD_DIR}"
  exit 1
fi

# Wait for Grafana to be ready
echo "Waiting for Grafana to be ready..."
for i in {1..30}; do
  if curl -sf "${GRAFANA_URL}/api/health" > /dev/null 2>&1; then
    echo "Grafana is ready."
    break
  fi
  if [[ $i -eq 30 ]]; then
    echo "ERROR: Grafana did not become ready in time."
    exit 1
  fi
  sleep 2
done

IMPORTED=0
FAILED=0

for dashboard_file in "$DASHBOARD_DIR"/*.json; do
  [[ -f "$dashboard_file" ]] || continue
  filename=$(basename "$dashboard_file")
  echo -n "  Importing ${filename}... "

  # Wrap the dashboard JSON in the import API payload
  payload=$(jq -c '{dashboard: ., overwrite: true}' < "$dashboard_file" | \
    jq '.dashboard.id = null')

  response=$(curl -sf -X POST "${GRAFANA_URL}/api/dashboards/db" \
    -H "Content-Type: application/json" \
    -u "admin:${ADMIN_PASSWORD}" \
    -d "$payload" 2>&1) && {
      echo "✓ OK"
      ((IMPORTED++))
    } || {
      echo "✗ FAILED"
      echo "    Response: ${response}"
      ((FAILED++))
    }
done

echo ""
echo "Done: ${IMPORTED} imported, ${FAILED} failed."
