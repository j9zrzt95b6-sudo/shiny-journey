#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CF_DIR="$ROOT_DIR/cloudflare"
ENV_FILE="$ROOT_DIR/.env.cloudflare"
ENV_LOCAL_FILE="$ROOT_DIR/.env.cloudflare.local"
CFG_FILE="$CF_DIR/wrangler.toml"

API_URL="https://smart-care-sync-api.j9zrzt95b6.workers.dev/state"
SYNC_KEY="healthcheck-$(date +%s)"
PUBLIC_ONLY=false

usage() {
  cat <<'EOF'
Usage: scripts/cloudflare-healthcheck.sh [API_URL] [--public-only] [--help]

Options:
  --public-only   Skip Cloudflare auth and D1 remote query; only probe public API behavior.
  --help          Show this help message.

Examples:
  ./scripts/cloudflare-healthcheck.sh
  ./scripts/cloudflare-healthcheck.sh --public-only
  ./scripts/cloudflare-healthcheck.sh "https://your-worker.workers.dev/state" --public-only
EOF
}

for arg in "$@"; do
  case "$arg" in
    --public-only)
      PUBLIC_ONLY=true
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    http://*|https://*)
      API_URL="$arg"
      ;;
    *)
      echo "Unknown option: $arg"
      usage
      exit 1
      ;;
  esac
done

if ! command -v node >/dev/null 2>&1; then
  echo "node not found. Please install Node.js first."
  exit 1
fi

if [[ "$PUBLIC_ONLY" != "true" ]]; then
  if ! command -v npx >/dev/null 2>&1; then
    echo "npx not found. Please install Node.js first."
    exit 1
  fi

  if [[ ! -f "$CFG_FILE" ]]; then
    echo "Missing $CFG_FILE"
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

  if [[ -z "${CLOUDFLARE_API_TOKEN:-}" || -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]]; then
    echo "Missing CLOUDFLARE_API_TOKEN or CLOUDFLARE_ACCOUNT_ID."
    echo "Set them in .env.cloudflare(.local) or export in shell."
    exit 1
  fi

  echo "[1/4] Checking Cloudflare auth..."
  npx --yes wrangler whoami --config "$CFG_FILE" >/dev/null

  echo "[2/4] Checking D1 accessibility..."
  npx --yes wrangler d1 execute smart-care-sync --remote --command "SELECT 1;" --config "$CFG_FILE" >/dev/null
else
  echo "[1/2] Public-only mode: skip Cloudflare auth and D1 CLI checks"
fi
echo "[$([[ "$PUBLIC_ONLY" == "true" ]] && echo "2/2" || echo "3/4")] API GET health check: $API_URL"
GET_RESP="$(curl -fsS "$API_URL?key=$SYNC_KEY")"

GET_OK="$(node -e 'const d=JSON.parse(process.argv[1]); process.stdout.write(String(Boolean(d.ok)));' "$GET_RESP")"
GET_STORAGE="$(node -e 'const d=JSON.parse(process.argv[1]); process.stdout.write(String(d.storage||""));' "$GET_RESP")"

if [[ "$GET_OK" != "true" ]]; then
  echo "GET check failed: $GET_RESP"
  exit 1
fi
if [[ "$GET_STORAGE" != "d1" ]]; then
  echo "GET check failed: expected storage=d1 but got '$GET_STORAGE'"
  exit 1
fi

echo "[$([[ "$PUBLIC_ONLY" == "true" ]] && echo "2/2" || echo "4/4")] API POST smoke check..."
POST_BODY='{"clients":[],"tasks":[],"records":[],"tokenShops":[],"tokenExchanges":[],"_meta":{"baseUpdatedAt":0,"lastSyncedAt":0,"deviceId":"healthcheck-script"}}'
POST_RESP="$(curl -fsS -X POST "$API_URL?key=$SYNC_KEY" -H "content-type: application/json" --data "$POST_BODY")"
POST_OK="$(node -e 'const d=JSON.parse(process.argv[1]); process.stdout.write(String(Boolean(d.ok)));' "$POST_RESP")"

if [[ "$POST_OK" != "true" ]]; then
  echo "POST check failed: $POST_RESP"
  exit 1
fi

echo "Health check passed. API is reachable and using D1."
