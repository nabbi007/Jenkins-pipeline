#!/bin/bash
# Setup Redis Exporter to collect Redis metrics

set -euo pipefail

REDIS_HOST="${1:-localhost}"
REDIS_PORT="${2:-6379}"

echo "Setting up Redis Exporter for Redis at $REDIS_HOST:$REDIS_PORT..."

# Check if redis-exporter is already running
if docker ps | grep -q redis-exporter; then
  echo "Redis exporter is already running"
  docker ps | grep redis-exporter
  exit 0
fi

# Start redis-exporter
echo "Starting redis-exporter on port 9121..."
docker run -d \
  --name redis-exporter \
  --restart unless-stopped \
  -p 9121:9121 \
  oliver006/redis_exporter:latest \
  --redis.addr=redis://$REDIS_HOST:$REDIS_PORT

echo "✓ Redis exporter started successfully"
echo "Metrics available at: http://localhost:9121/metrics"
docker ps | grep redis-exporter
