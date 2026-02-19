#!/usr/bin/env bash
set -euo pipefail

PLUGINS_FILE="${1:-jenkins/plugins.txt}"

if ! command -v jenkins-plugin-cli >/dev/null 2>&1; then
  echo "jenkins-plugin-cli not found. Install Jenkins plugin manager first."
  exit 1
fi

jenkins-plugin-cli --plugin-file "$PLUGINS_FILE"
