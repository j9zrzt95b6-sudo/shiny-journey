#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
START_PORT="${1:-8001}"
PORT="$START_PORT"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 not found"
  exit 1
fi

if command -v lsof >/dev/null 2>&1; then
  while lsof -i ":${PORT}" >/dev/null 2>&1; do
    PORT="$((PORT + 1))"
  done
fi

LOCAL_URL="http://127.0.0.1:${PORT}"
FORWARD_URL=""
if [[ -n "${CODESPACE_NAME:-}" && -n "${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-}" ]]; then
  FORWARD_URL="https://${CODESPACE_NAME}-${PORT}.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
fi

echo "Starting preview server..."
echo "Workspace: ${ROOT_DIR}"
echo "Port: ${PORT}"
echo "Local URL: ${LOCAL_URL}"
if [[ -n "$FORWARD_URL" ]]; then
  echo "Forward URL: ${FORWARD_URL}"
fi
echo ""
echo "Tip: If browser is stuck at connecting, open the port from VS Code Ports panel and set visibility to Public."

cd "$ROOT_DIR"
python3 -m http.server "$PORT"
