#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CF_DIR="$ROOT_DIR/cloudflare"
ENV_FILE="$ROOT_DIR/.env.cloudflare"
ENV_LOCAL_FILE="$ROOT_DIR/.env.cloudflare.local"
CONFIG_FILE="$CF_DIR/wrangler.toml"
CONFIG_TEMPLATE="$CF_DIR/wrangler.toml.example"
ENV_TEMPLATE="$ROOT_DIR/.env.cloudflare.example"
WORKDIR="$CF_DIR"
DRY_RUN=false
VERBOSE=false
VERIFY_PUBLIC=false
API_URL="https://smart-care-sync-api.j9zrzt95b6.workers.dev/state"

resolve_path_from_root() {
  local path="$1"
  if [[ "$path" = /* ]]; then
    echo "$path"
  else
    echo "$ROOT_DIR/$path"
  fi
}

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

prefer_existing_secret() {
  local var_name="$1"
  local original_value="$2"
  local current_value="${!var_name:-}"

  # Keep the real value already set in the shell when env files contain placeholders.
  if [[ -n "$original_value" ]] && ! looks_like_placeholder "$original_value"; then
    if [[ -z "$current_value" ]] || looks_like_placeholder "$current_value"; then
      printf -v "$var_name" '%s' "$original_value"
      export "$var_name"
    fi
  fi
}

looks_like_placeholder() {
  local value="${1:-}"
  if [[ -z "$value" ]]; then
    return 0
  fi
  local lowered
  lowered="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
  if [[ "$lowered" =~ (your_|replace|changeme|todo|example|sample|dummy|test|token_here|account_id_here) ]]; then
    return 0
  fi
  if [[ "$value" =~ (你的|請填|示範|範例|真實token|真實token值) ]]; then
    return 0
  fi
  if [[ "$value" =~ ^[xX*._-]+$ ]]; then
    return 0
  fi
  return 1
}

usage() {
  cat <<'EOF'
Usage: scripts/deploy-cloudflare.sh [options]

Options:
  --dry-run         Only run preflight checks; do not deploy.
  --verbose         Print extra diagnostics during preflight/deploy.
  --verify-public   Run public API healthcheck after deploy (requires scripts/cloudflare-healthcheck.sh).
  --api-url <url>   API base URL for post-deploy public verification.
  --config <path>   Use a custom Wrangler config path (relative paths resolve from the repo root).
  --env-file <path> Load Cloudflare credentials from a custom env file.
  --env-file-local <path> Load Cloudflare credentials from a second custom env file.
  --help            Show this help message.
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
    --config)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --config"
        usage
        exit 1
      fi
      CONFIG_FILE="$2"
      shift 2
      ;;
    --env-file)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --env-file"
        usage
        exit 1
      fi
      ENV_FILE="$2"
      shift 2
      ;;
    --env-file-local)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --env-file-local"
        usage
        exit 1
      fi
      ENV_LOCAL_FILE="$2"
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

CONFIG_FILE="$(resolve_path_from_root "$CONFIG_FILE")"
ENV_FILE="$(resolve_path_from_root "$ENV_FILE")"
ENV_LOCAL_FILE="$(resolve_path_from_root "$ENV_LOCAL_FILE")"
WORKDIR="$(dirname "$CONFIG_FILE")"

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
  if [[ -f "$CONFIG_TEMPLATE" ]]; then
    info "Creating $CONFIG_FILE from $CONFIG_TEMPLATE"
    cp "$CONFIG_TEMPLATE" "$CONFIG_FILE"
  else
    echo "Missing $CONFIG_FILE"
    echo "Please copy wrangler.toml.example -> wrangler.toml and fill D1 database_id (and optional KV id)"
    exit 1
  fi
fi
vlog "config file found: $CONFIG_FILE"
vlog "env file: $ENV_FILE"
vlog "local env file: $ENV_LOCAL_FILE"

cd "$WORKDIR"
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
ORIGINAL_CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN:-}"
ORIGINAL_CLOUDFLARE_ACCOUNT_ID="${CLOUDFLARE_ACCOUNT_ID:-}"

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

prefer_existing_secret "CLOUDFLARE_API_TOKEN" "$ORIGINAL_CLOUDFLARE_API_TOKEN"
prefer_existing_secret "CLOUDFLARE_ACCOUNT_ID" "$ORIGINAL_CLOUDFLARE_ACCOUNT_ID"

if [[ ! -f "$ENV_FILE" && ! -f "$ENV_LOCAL_FILE" ]]; then
  if [[ -f "$ENV_TEMPLATE" ]]; then
    warn "No .env.cloudflare(.local) file found. Creating $ENV_FILE from $ENV_TEMPLATE"
    cp "$ENV_TEMPLATE" "$ENV_FILE"
  else
    warn "No .env.cloudflare(.local) file found. Falling back to current shell environment."
  fi
fi

TOKEN_VALUE="${CLOUDFLARE_API_TOKEN:-}"
ACCOUNT_ID_VALUE="${CLOUDFLARE_ACCOUNT_ID:-}"

TOKEN_HAS_NON_ASCII=false
if [[ -n "$TOKEN_VALUE" ]] && printf '%s' "$TOKEN_VALUE" | LC_ALL=C grep -q '[^ -~]'; then
  TOKEN_HAS_NON_ASCII=true
fi

if [[ -z "$TOKEN_VALUE" || -z "$ACCOUNT_ID_VALUE" ]] || looks_like_placeholder "$TOKEN_VALUE" || looks_like_placeholder "$ACCOUNT_ID_VALUE"; then
  if [[ "$DRY_RUN" == "true" ]]; then
    warn "Cloudflare credentials are still placeholders or not set."
    if [[ "$TOKEN_HAS_NON_ASCII" == "true" ]]; then
      warn "CLOUDFLARE_API_TOKEN contains non-ASCII characters (usually from placeholder/demo text)."
    fi
    warn "Edit $ENV_FILE or $ENV_LOCAL_FILE and fill in real values before a real deploy."
    info "Dry run completed. No deployment was performed."
    exit 0
  fi

  echo "Missing or placeholder CLOUDFLARE_API_TOKEN or CLOUDFLARE_ACCOUNT_ID."
  echo "Export real values, or set them in $ENV_FILE / $ENV_LOCAL_FILE, then re-run this script."
  echo "Example:"
  echo "  export CLOUDFLARE_API_TOKEN='your_token'"
  echo "  export CLOUDFLARE_ACCOUNT_ID='your_account_id'"
  echo "Or create: $ENV_LOCAL_FILE"
  exit 1
fi

if [[ "$TOKEN_HAS_NON_ASCII" == "true" ]]; then
  echo "Invalid CLOUDFLARE_API_TOKEN: contains non-ASCII characters."
  echo "Please paste a real token value (usually starts with 'cf')."
  exit 1
fi

if [[ -n "$TOKEN_VALUE" ]] && [[ ! "$TOKEN_VALUE" =~ ^cf ]]; then
  warn "CLOUDFLARE_API_TOKEN does not start with 'cf'. Please confirm token value."
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
