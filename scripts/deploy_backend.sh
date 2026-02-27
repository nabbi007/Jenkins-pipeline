#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${1:?Usage: deploy_backend.sh <region> <account_id> <repo> <tag> <log_group>}"
AWS_ACCOUNT_ID="${2:?Usage: deploy_backend.sh <region> <account_id> <repo> <tag> <log_group>}"
ECR_REPOSITORY="${3:-backend-service}"
IMAGE_TAG="${4:-latest}"
LOG_GROUP="${5:-/project/backend}"

IMAGE_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}"

aws ecr get-login-password --region "${AWS_REGION}" | \
  docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

docker network inspect app-net >/dev/null 2>&1 || docker network create app-net

# Ensure Redis is running before the backend starts.
if ! docker ps --format '{{.Names}}' | grep -q '^redis$'; then
  docker rm -f redis >/dev/null 2>&1 || true
  docker run -d \
    --name redis \
    --restart unless-stopped \
    --network app-net \
    -p 6379:6379 \
    -v redis_votes:/data \
    redis:7.2-alpine redis-server --appendonly yes
  echo "Redis container started"
else
  echo "Redis already running"
fi

docker pull "${IMAGE_URI}"
docker rm -f backend >/dev/null 2>&1 || true

docker run -d \
  --name backend \
  --restart unless-stopped \
  --network app-net \
  -p 3000:3000 \
  -e REDIS_URL=redis://redis:6379 \
  --log-driver=awslogs \
  --log-opt awslogs-region="${AWS_REGION}" \
  --log-opt awslogs-group="${LOG_GROUP}" \
  --log-opt awslogs-stream="backend" \
  "${IMAGE_URI}"

docker image prune -f >/dev/null 2>&1 || true
