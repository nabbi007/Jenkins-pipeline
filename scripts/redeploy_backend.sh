#!/bin/bash
# Rebuild and redeploy backend with new metrics

set -euo pipefail

DEPLOY_HOST="${1:-54.78.54.132}"
SSH_KEY="${2:-infra/terraform/jenkins-cicd-observability-ec2-27035621.pem}"

echo "=== Building Backend with Enhanced Metrics ==="
cd backend
echo "Building Docker image..."
docker build -t voting-backend:latest .

echo ""
echo "=== Deploying to $DEPLOY_HOST ==="
docker save voting-backend:latest | gzip > /tmp/backend-image.tar.gz
scp -i "../$SSH_KEY" -o StrictHostKeyChecking=no /tmp/backend-image.tar.gz ec2-user@$DEPLOY_HOST:/tmp/

ssh -i "../$SSH_KEY" -o StrictHostKeyChecking=no ec2-user@$DEPLOY_HOST "
  echo 'Loading Docker image...'
  docker load < /tmp/backend-image.tar.gz
  
  echo 'Stopping old backend container...'
  docker stop backend 2>/dev/null || true
  docker rm backend 2>/dev/null || true
  
  echo 'Starting new backend container...'
  docker run -d \
    --name backend \
    --network host \
    -e REDIS_URL=redis://localhost:6379 \
    --restart unless-stopped \
    voting-backend:latest
  
  sleep 3
  
  echo ''
  echo '=== Verifying Deployment ==='
  docker ps --filter name=backend --format 'Container: {{.Names}} - Status: {{.Status}}'
  
  echo ''
  echo 'Testing metrics endpoint...'
  curl -s http://localhost:3000/metrics | grep -E '^(votes_|http_request|redis_connection)' | head -10
  
  echo ''
  echo '✓ Backend redeployed with enhanced metrics!'
  
  rm /tmp/backend-image.tar.gz
"

rm /tmp/backend-image.tar.gz

echo ""
echo "=== Enhanced Metrics Available ==="
echo "Business Metrics:"
echo "  - votes_total (counter by option)"
echo "  - votes_current (gauge by option)"
echo "  - votes_total_count (total gauge)"
echo "  - poll_views_total (counter)"
echo "  - results_views_total (counter)"
echo ""
echo "Operational Metrics:"
echo "  - redis_connection_status (gauge)"
echo "  - http_requests_in_progress (gauge)"
echo "  - http_request_duration_seconds (histogram with better buckets)"
echo ""
echo "Access backend metrics: http://$DEPLOY_HOST:3000/metrics"
