#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${1:?Usage: deploy_frontend.sh <region> <account_id> <repo> <tag> <log_group>}"
AWS_ACCOUNT_ID="${2:?Usage: deploy_frontend.sh <region> <account_id> <repo> <tag> <log_group>}"
ECR_REPOSITORY="${3:-frontend-web}"
IMAGE_TAG="${4:-latest}"
LOG_GROUP="${5:-/project/frontend}"

IMAGE_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}"

aws ecr get-login-password --region "${AWS_REGION}" | \
  docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

docker network inspect app-net >/dev/null 2>&1 || docker network create app-net

docker pull "${IMAGE_URI}"
docker rm -f frontend >/dev/null 2>&1 || true

docker run -d \
  --name frontend \
  --restart unless-stopped \
  --network app-net \
  -p 80:80 \
  --log-driver=awslogs \
  --log-opt awslogs-region="${AWS_REGION}" \
  --log-opt awslogs-group="${LOG_GROUP}" \
  --log-opt awslogs-stream="frontend" \
  "${IMAGE_URI}"

docker image prune -f >/dev/null 2>&1 || true
