#!/usr/bin/env bash
set -euo pipefail

TARGET_URL="${1:?Usage: generate_error_traffic.sh <base_url> [requests]}"
REQUESTS="${2:-100}"

for i in $(seq 1 "$REQUESTS"); do
  curl -s -o /dev/null -w "%{http_code}\n" "${TARGET_URL%/}/api/fail" || true
  sleep 0.2
done
