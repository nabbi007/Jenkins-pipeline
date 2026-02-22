#!/bin/bash
# Quick dashboard import helper

GRAFANA_URL="http://108.130.163.21:3000"

echo "========================================="
echo "Grafana Dashboard Import Helper"
echo "========================================="
echo ""
echo "1. Open Grafana: $GRAFANA_URL"
echo "   Login: admin / admin"
echo ""
echo "2. Click '+' (Create) → Import"
echo ""
echo "3. Upload these dashboards:"
echo "   📊 Application Metrics: observability/grafana/app-metrics-dashboard.json"
echo "   💻 System Metrics: observability/grafana/system-metrics-dashboard.json"
echo "   🔴 Redis Metrics: observability/grafana/redis-metrics-dashboard.json"
echo ""
echo "4. For each dashboard:"
echo "   - Click 'Upload JSON file' OR copy-paste the content"
echo "   - Select 'Prometheus' as datasource"
echo "   - Click 'Import'"
echo ""
echo "========================================="
echo "Or use this command to import automatically:"
echo "========================================="
echo ""

for DASHBOARD in observability/grafana/*-dashboard.json; do
  if [ -f "$DASHBOARD" ]; then
    BASENAME=$(basename "$DASHBOARD")
    echo "curl '$GRAFANA_URL/api/dashboards/import' \\"
    echo "  -u admin:admin \\"
    echo "  -H 'Content-Type: application/json' \\"
    echo "  -d @$DASHBOARD"
    echo ""
  fi
done

echo "========================================="
echo "Dashboards available at: $GRAFANA_URL/dashboards"
echo "========================================="
