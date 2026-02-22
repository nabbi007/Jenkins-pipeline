#!/bin/bash
# Master script to deploy complete observability stack

set -euo pipefail

echo "========================================="
echo "Deploying Complete Observability Stack"
echo "========================================="

# Get EC2 IPs from terraform
cd /home/lliasububakar/jenkins-project/infra/terraform
APP_IP=$(terraform output -raw jenkins_public_ip)
OBS_IP=$(terraform output -raw observability_public_ip)
SSH_KEY="/home/lliasububakar/jenkins-project/infra/terraform/jenkins-cicd-observability-ec2-27035621.pem"

echo ""
echo "Infrastructure:"
echo "  App EC2:          $APP_IP"
echo "  Observability EC2: $OBS_IP"
echo ""

cd /home/lliasububakar/jenkins-project

# Step 1: Deploy node-exporter on app EC2
echo "Step 1/5: Deploying node-exporter on app EC2..."
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no \
  scripts/setup_node_exporter.sh ec2-user@$APP_IP:/tmp/
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ec2-user@$APP_IP \
  "chmod +x /tmp/setup_node_exporter.sh && sudo /tmp/setup_node_exporter.sh"
echo "✓ Node exporter deployed"
echo ""

# Step 2: Deploy Loki on observability EC2
echo "Step 2/5: Deploying Loki on observability EC2..."
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no \
  scripts/setup_loki_stack.sh ec2-user@$OBS_IP:/tmp/
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ec2-user@$OBS_IP \
  "chmod +x /tmp/setup_loki_stack.sh && sudo /tmp/setup_loki_stack.sh $APP_IP"
echo "✓ Loki deployed"
echo ""

# Step 3: Deploy Promtail on app EC2
echo "Step 3/5: Deploying Promtail on app EC2..."
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no \
  scripts/setup_promtail_app.sh ec2-user@$APP_IP:/tmp/
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ec2-user@$APP_IP \
  "chmod +x /tmp/setup_promtail_app.sh && sudo /tmp/setup_promtail_app.sh http://$OBS_IP:3100"
echo "✓ Promtail deployed"
echo ""

# Step 4: Configure Grafana datasources
echo "Step 4/5: Configuring Grafana datasources..."
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no \
  scripts/update_grafana_datasources.sh ec2-user@$OBS_IP:/tmp/
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ec2-user@$OBS_IP \
  "chmod +x /tmp/update_grafana_datasources.sh && /tmp/update_grafana_datasources.sh http://localhost:3000 admin admin"
echo "✓ Grafana datasources configured"
echo ""

# Step 5: Import Grafana dashboards
echo "Step 5/5: Importing Grafana dashboards..."
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no \
  observability/grafana/*.json ec2-user@$OBS_IP:/tmp/
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ec2-user@$OBS_IP \
  'for dashboard in /tmp/*.json; do
    curl -X POST http://localhost:3000/api/dashboards/db \
      -H "Content-Type: application/json" \
      -u admin:admin \
      -d "{\"dashboard\": $(cat $dashboard), \"overwrite\": true}" 2>/dev/null || true
  done'
echo "✓ Dashboards imported"
echo ""

# Verification
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""
echo "Access Points:"
echo "  Frontend:    http://$APP_IP"
echo "  Backend API: http://$APP_IP:3000/api/health"
echo "  Metrics:     http://$APP_IP:3000/metrics"
echo "  Jenkins:     http://$APP_IP:8080"
echo ""
echo "Observability Stack:"
echo "  Grafana:     http://$OBS_IP:3000  (admin / admin)"
echo "  Prometheus:  http://$OBS_IP:9090"
echo "  Loki:        http://$OBS_IP:3100"
echo ""
echo "Next Steps:"
echo "  1. Open Grafana: http://$OBS_IP:3000"
echo "  2. Login with admin / admin"
echo "  3. View dashboards:"
echo "     - Full Stack Observability (metrics + logs)"
echo "     - Backend Service Overview (app metrics)"
echo ""
