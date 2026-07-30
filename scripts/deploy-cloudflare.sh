#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CF_DIR="$ROOT_DIR/cloudflare"
ENV_FILE="$ROOT_DIR/.env.cloudflare"
ENV_LOCAL_FILE="$ROOT_DIR/.env.cloudflare.local"
CONFIG_FILE="$CF_DIR/wrangler.toml"
DRY_RUN=false
VERBOSE=false
VERIFY_PUBLIC=false
API_URL="https://smart-care-sync-api.j9zrzt95b6.workers.dev/state"

info() {
  echo "[INFO] $*"
}

warn() {
  echo "[WARN] $*"
}

vlog() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo "[VERBOSE] $*"
  fi
}

usage() {
  cat <<'EOF'
Usage: scripts/deploy-cloudflare.sh [--dry-run] [--verbose] [--verify-public] [--api-url <url>] [--help]

Options:
  --dry-run   Only run preflight checks; do not deploy.
  --verbose   Print extra diagnostics during preflight/deploy.
  --verify-public  Run public API healthcheck after deploy (requires scripts/cloudflare-healthcheck.sh).
  --api-url   API base URL for post-deploy public verification.
  --help      Show this help message.
EOF
}

while [[ $# -gt 0 ]]; do
  arg="$1"
  case "$arg" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
    --verify-public)
      VERIFY_PUBLIC=true
      shift
      ;;
    --api-url)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --api-url"
        usage
        exit 1
      fi
      API_URL="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $arg"
      usage
      exit 1
      ;;
  esac
done

if ! command -v npx >/dev/null 2>&1; then
  echo "npx not found. Please install Node.js first."
  exit 1
fi
vlog "npx detected: $(command -v npx)"

if ! command -v node >/dev/null 2>&1; then
  echo "node not found. Please install Node.js first."
  exit 1
fi
vlog "node detected: $(command -v node)"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Missing $CONFIG_FILE"
  echo "Please copy wrangler.toml.example -> wrangler.toml and fill D1 database_id (and optional KV id)"
  exit 1
fi
vlog "config file found: $CONFIG_FILE"

cd "$CF_DIR"
vlog "working directory: $PWD"

if ! grep -Eq '^database_id\s*=\s*"[0-9a-fA-F-]{36}"' "$CONFIG_FILE"; then
  echo "Invalid or missing D1 database_id in $CONFIG_FILE"
  echo "Please set [[d1_databases]].database_id to a real UUID."
  exit 1
fi

if grep -Eqi 'REPLACE|YOUR_|CHANGEME|TODO' "$CONFIG_FILE"; then
  echo "$CONFIG_FILE still contains placeholder text (REPLACE/YOUR_/CHANGEME/TODO)."
  echo "Please fill all required values before deploy."
  exit 1
fi
vlog "wrangler.toml preflight checks passed"

# Auto-load Cloudflare credentials from local env files to avoid retyping
# in new terminal sessions. Values already present in current env take precedence.
if [[ -f "$ENV_FILE" ]]; then
  vlog "loading env file: $ENV_FILE"
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi
if [[ -f "$ENV_LOCAL_FILE" ]]; then
  vlog "loading env file: $ENV_LOCAL_FILE"
  set -a
  # shellcheck disable=SC1090
  source "$ENV_LOCAL_FILE"
  set +a
fi

if [[ ! -f "$ENV_FILE" && ! -f "$ENV_LOCAL_FILE" ]]; then
  warn "No .env.cloudflare(.local) file found. Falling back to current shell environment."
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

if [[ "$DRY_RUN" == "true" ]]; then
  info "Preflight checks passed. --dry-run set, skipping deploy."
  exit 0
fi

info "Deploying Cloudflare Worker..."
npx --yes wrangler deploy --config "$CONFIG_FILE"

if [[ "$VERIFY_PUBLIC" == "true" ]]; then
  HEALTHCHECK_SCRIPT="$ROOT_DIR/scripts/cloudflare-healthcheck.sh"
  if [[ ! -x "$HEALTHCHECK_SCRIPT" ]]; then
    if [[ ! -f "$HEALTHCHECK_SCRIPT" ]]; then
      echo "Public verification skipped: missing $HEALTHCHECK_SCRIPT"
    else
      echo "Public verification skipped: $HEALTHCHECK_SCRIPT is not executable"
      echo "Run: chmod +x $HEALTHCHECK_SCRIPT"
    fi
  else
    info "Running public verification on $API_URL ..."
    bash "$HEALTHCHECK_SCRIPT" "$API_URL" --public-only
  fi
fi

info "Done. Use the returned workers.dev URL as the sync API base URL in settings."
