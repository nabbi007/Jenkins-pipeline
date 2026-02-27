#!/bin/bash
# Verify and test the complete observability stack

set -euo pipefail

echo "========================================="
echo "Observability Stack Verification"
echo "========================================="
echo ""

# Get IPs
cd /home/lliasububakar/jenkins-project/infra/terraform
APP_IP=$(terraform output -raw jenkins_public_ip)
OBS_IP=$(terraform output -raw observability_public_ip)
SSH_KEY="/home/lliasububakar/jenkins-project/infra/terraform/jenkins-cicd-observability-ec2-27035621.pem"

echo "Infrastructure:"
echo "  App EC2:          $APP_IP"
echo "  Observability EC2: $OBS_IP"
echo ""

# Test 1: Check node_exporter on app EC2
echo "1. Checking node_exporter on app EC2..."
if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ec2-user@$APP_IP "systemctl is-active node_exporter" 2>/dev/null; then
  echo "   ✓ Node exporter service is running"
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ec2-user@$APP_IP "curl -s localhost:9100/metrics | head -3"
else
  echo "   ✗ Node exporter is not running!"
fi
echo ""

# Test 2: Check Prometheus on observability EC2
echo "2. Checking Prometheus on observability EC2..."
if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ec2-user@$OBS_IP "docker ps | grep prometheus" >/dev/null 2>&1; then
  echo "   ✓ Prometheus container is running"
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ec2-user@$OBS_IP \
    "curl -s localhost:9090/api/v1/targets 2>/dev/null | grep -o '\"health\":\"[^\"]*\"' | sort | uniq -c"
else
  echo "   ✗ Prometheus is not running!"
fi
echo ""

# Test 3: Check Grafana on observability EC2
echo "3. Checking Grafana on observability EC2..."
if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ec2-user@$OBS_IP "docker ps | grep grafana" >/dev/null 2>&1; then
  echo "   ✓ Grafana container is running"
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ec2-user@$OBS_IP \
    "curl -s localhost:3000/api/health 2>/dev/null"
  echo ""
else
  echo "   ✗ Grafana is not running!"
fi
echo ""

# Test 4: Check Loki on observability EC2
echo "4. Checking Loki on observability EC2..."
if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ec2-user@$OBS_IP "docker ps | grep loki" >/dev/null 2>&1; then
  echo "   ✓ Loki container is running"
else
  echo "   ✗ Loki is not running!"
fi
echo ""

# Test 5: Check Promtail on app EC2
echo "5. Checking Promtail on app EC2..."
if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ec2-user@$APP_IP "docker ps | grep promtail" >/dev/null 2>&1; then
  echo "   ✓ Promtail container is running"
else
  echo "   ✗ Promtail is not running!"
fi
echo ""

# Test 6: Check backend metrics
echo "6. Checking backend metrics..."
if curl -sf http://$APP_IP:3000/metrics >/dev/null 2>&1; then
  echo "   ✓ Backend /metrics endpoint is accessible"
  curl -s http://$APP_IP:3000/metrics | grep -E "http_requests_total|http_request_duration" | head -3
else
  echo "   ✗ Backend metrics not accessible!"
fi
echo ""

# Test 7: List Grafana datasources
echo "7. Checking Grafana datasources..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ec2-user@$OBS_IP \
  "curl -s localhost:3000/api/datasources -u admin:admin 2>/dev/null" | \
  grep -oE '"name":"[^"]+"|"type":"[^"]+"' | paste - - | head -5 || echo "   Could not fetch datasources"
echo ""

# Test 8: List Grafana dashboards
echo "8. Checking Grafana dashboards..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ec2-user@$OBS_IP \
  "curl -s localhost:3000/api/search -u admin:admin 2>/dev/null" | \
  grep -oE '"title":"[^"]+"' || echo "   Could not fetch dashboards"
echo ""

echo "========================================="
echo "Access URLs:"
echo "========================================="
echo ""
echo "Grafana:     http://$OBS_IP:3000"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo "Prometheus:  http://$OBS_IP:9090"
echo ""
echo "App URLs:"
echo "  Frontend:  http://$APP_IP"
echo "  Backend:   http://$APP_IP:3000/api/health"
echo "  Metrics:   http://$APP_IP:3000/metrics"
echo ""
