#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CF_DIR="$ROOT_DIR/cloudflare"
ENV_FILE="$ROOT_DIR/.env.cloudflare"
ENV_LOCAL_FILE="$ROOT_DIR/.env.cloudflare.local"

if ! command -v npx >/dev/null 2>&1; then
  echo "npx not found. Please install Node.js first."
  exit 1
fi

if [[ ! -f "$CF_DIR/wrangler.toml" ]]; then
  echo "Missing $CF_DIR/wrangler.toml"
  echo "Please copy wrangler.toml.example -> wrangler.toml and fill D1 database_id (and optional KV id)"
  exit 1
fi

cd "$CF_DIR"

# Auto-load Cloudflare credentials from local env files to avoid retyping
# in new terminal sessions. Values already present in current env take precedence.
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi
if [[ -f "$ENV_LOCAL_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_LOCAL_FILE"
  set +a
fi

if [[ -z "${CLOUDFLARE_API_TOKEN:-}" || -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]]; then
  echo "Missing CLOUDFLARE_API_TOKEN or CLOUDFLARE_ACCOUNT_ID."
  echo "Export both variables, or set them in .env.cloudflare(.local), then re-run this script."
  echo "Example:"
  echo "  export CLOUDFLARE_API_TOKEN='your_token'"
  echo "  export CLOUDFLARE_ACCOUNT_ID='your_account_id'"
  echo "Or create: $ENV_FILE"
  exit 1
fi

echo "Deploying Cloudflare Worker..."
npx --yes wrangler deploy --config "$CF_DIR/wrangler.toml"

echo "Done. Use the returned workers.dev URL + /state (if configured via route) as sync API URL in settings."
