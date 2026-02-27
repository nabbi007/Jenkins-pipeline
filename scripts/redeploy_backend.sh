#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────
# redeploy_backend.sh
#
# Force-redeploys the backend container on the current instance
# by pulling the latest image from ECR and restarting the container.
#
# Usage:
#   ./redeploy_backend.sh [REGION] [ACCOUNT_ID] [REPO] [TAG]
#
# Defaults pull the latest tag from the ECR repo.
# ────────────────────────────────────────────────────────────────
set -euo pipefail

AWS_REGION="${1:-eu-west-1}"
AWS_ACCOUNT_ID="${2:-$(aws sts get-caller-identity --query Account --output text)}"
ECR_REPOSITORY="${3:-backend-service}"
IMAGE_TAG="${4:-latest}"

IMAGE_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "================================================="
echo "  Backend Redeployment"
echo "================================================="
echo "  Image: ${IMAGE_URI}"
echo ""

# ── If tag is "latest", discover the most recent image tag ──────
if [[ "$IMAGE_TAG" == "latest" ]]; then
  echo "No specific tag provided — finding the latest image in ECR..."
  LATEST_TAG=$(aws ecr describe-images \
    --region "$AWS_REGION" \
    --repository-name "$ECR_REPOSITORY" \
    --query 'sort_by(imageDetails,& imagePushedAt)[-1].imageTags[0]' \
    --output text 2>/dev/null) || true

  if [[ -n "$LATEST_TAG" && "$LATEST_TAG" != "None" ]]; then
    IMAGE_TAG="$LATEST_TAG"
    IMAGE_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}"
    echo "  Resolved latest tag: ${IMAGE_TAG}"
  else
    echo "  WARNING: Could not determine latest tag. Using 'latest'."
  fi
fi

# ── Login to ECR ────────────────────────────────────────────────
echo "Logging in to ECR..."
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$ECR_REGISTRY"

# ── Ensure app-net exists ───────────────────────────────────────
docker network inspect app-net >/dev/null 2>&1 || docker network create app-net

# ── Ensure Redis is running ─────────────────────────────────────
if ! docker ps --format '{{.Names}}' | grep -q '^redis$'; then
  docker rm -f redis 2>/dev/null || true
  docker run -d \
    --name redis \
    --restart unless-stopped \
    --network app-net \
    -p 6379:6379 \
    -v redis_votes:/data \
    redis:7.2-alpine redis-server --appendonly yes
  echo "Redis container started."
else
  echo "Redis already running."
fi

# ── Pull and redeploy backend ──────────────────────────────────
echo "Pulling image..."
docker pull "$IMAGE_URI"

echo "Stopping old container..."
docker rm -f backend 2>/dev/null || true

echo "Starting new container..."
docker run -d \
  --name backend \
  --restart unless-stopped \
  --network app-net \
  -p 3000:3000 \
  -e REDIS_URL=redis://redis:6379 \
  "$IMAGE_URI"

# ── Cleanup ─────────────────────────────────────────────────────
docker image prune -f >/dev/null 2>&1 || true

echo ""
echo "✓ Backend redeployed successfully"
echo "  Image: ${IMAGE_URI}"
echo "  Health check: curl http://localhost:3000/api/health"
