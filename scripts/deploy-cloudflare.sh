#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CF_DIR="$ROOT_DIR/cloudflare"

if ! command -v npx >/dev/null 2>&1; then
  echo "npx not found. Please install Node.js first."
  exit 1
fi

if [[ ! -f "$CF_DIR/wrangler.toml" ]]; then
  echo "Missing $CF_DIR/wrangler.toml"
  echo "Please copy wrangler.toml.example -> wrangler.toml and fill KV namespace id"
  exit 1
fi

cd "$CF_DIR"

echo "Deploying Cloudflare Worker..."
npx --yes wrangler deploy

echo "Done. Use the returned workers.dev URL + /state (if configured via route) as sync API URL in settings."
