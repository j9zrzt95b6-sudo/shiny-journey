#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env.netlify"
ENV_LOCAL_FILE="$ROOT_DIR/.env.netlify.local"
SITE_NAME="smartcare-static"

if ! command -v npx >/dev/null 2>&1; then
  echo "npx not found. Please install Node.js first."
  exit 1
fi

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

if [[ -z "${NETLIFY_AUTH_TOKEN:-}" ]]; then
  echo "Missing NETLIFY_AUTH_TOKEN."
  echo "Set it in .env.netlify(.local) or export it in shell."
  echo "Example:"
  echo "  export NETLIFY_AUTH_TOKEN='your_token'"
  echo "Or create: $ENV_FILE"
  exit 1
fi

cd "$ROOT_DIR"

if [[ -z "${NETLIFY_SITE_ID:-}" ]]; then
  echo "Creating Netlify site if needed..."
  CREATE_JSON="$(npx --yes netlify-cli sites:create --name "$SITE_NAME" --disable-linking --json --auth "$NETLIFY_AUTH_TOKEN")"
  SITE_ID="$(node -e 'const data = JSON.parse(process.argv[1]); const site = data.site || data; const id = site.id || site.site_id || site.siteId || site.siteID || ""; if (!id) process.exit(1); process.stdout.write(id);' "$CREATE_JSON")"
  if [[ -z "$SITE_ID" ]]; then
    echo "Could not parse Netlify site ID from create response."
    echo "$CREATE_JSON"
    exit 1
  fi
  echo "Using created site ID: $SITE_ID"
else
  SITE_ID="$NETLIFY_SITE_ID"
fi

echo "Deploying to Netlify (production)..."
npx --yes netlify-cli deploy \
  --prod \
  --dir . \
  --functions netlify/functions \
  --site "$SITE_ID" \
  --auth "$NETLIFY_AUTH_TOKEN"

echo "Done."
