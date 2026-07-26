#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v npx >/dev/null 2>&1; then
  echo "npx not found. Please install Node.js first."
  exit 1
fi

echo "Checking Netlify login status..."
if ! npx --yes netlify-cli status >/dev/null 2>&1; then
  echo "Not logged in to Netlify."
  echo "Run: npx --yes netlify-cli login"
  exit 1
fi

cd "$ROOT_DIR"

echo "Deploying to Netlify (production)..."
npx --yes netlify-cli deploy \
  --prod \
  --dir . \
  --functions netlify/functions

echo "Done."
