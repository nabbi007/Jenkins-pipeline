#!/usr/bin/env bash
set -euo pipefail

docker container prune -f || true
docker image prune -af || true
docker volume prune -f || true
