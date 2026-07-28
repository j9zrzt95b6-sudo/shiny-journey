#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CF_DIR="$ROOT_DIR/cloudflare"
CFG_FILE="$CF_DIR/wrangler.toml"
SCHEMA_FILE="$CF_DIR/schema.sql"

if ! command -v npx >/dev/null 2>&1; then
	echo "npx not found. Please install Node.js first."
	exit 1
fi

if [[ -z "${CLOUDFLARE_API_TOKEN:-}" || -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]]; then
	echo "Missing Cloudflare credentials in environment variables."
	echo "Run these in your terminal first:"
	echo '  export CLOUDFLARE_API_TOKEN="<YOUR_API_TOKEN>"'
	echo '  export CLOUDFLARE_ACCOUNT_ID="<YOUR_ACCOUNT_ID>"'
	exit 1
fi

if [[ ! -f "$CFG_FILE" ]]; then
	cp "$CF_DIR/wrangler.toml.example" "$CFG_FILE"
fi

if [[ ! -f "$SCHEMA_FILE" ]]; then
	echo "Missing schema file: $SCHEMA_FILE"
	exit 1
fi

# Remove optional KV block when placeholder ID is still present to avoid deploy failure.
if grep -q 'REPLACE_WITH_YOUR_KV_NAMESPACE_ID' "$CFG_FILE"; then
	awk '
		BEGIN { skip = 0 }
		/^\[\[kv_namespaces\]\]/ { skip = 1; next }
		skip == 1 && /^\[/ { skip = 0 }
		skip == 0 { print }
	' "$CFG_FILE" > "$CFG_FILE.tmp" && mv "$CFG_FILE.tmp" "$CFG_FILE"
fi

echo "Checking Cloudflare auth..."
npx --yes wrangler whoami --config "$CFG_FILE"

if grep -q 'REPLACE_WITH_YOUR_D1_DATABASE_ID' "$CFG_FILE"; then
	echo "Creating D1 database and updating config..."
	CREATE_LOG="$(mktemp)"
	if ! npx --yes wrangler d1 create smart-care-sync \
		--binding SMART_CARE_D1 \
		--config "$CFG_FILE" | tee "$CREATE_LOG"; then
		echo "D1 database creation failed."
		rm -f "$CREATE_LOG"
		exit 1
	fi

	DB_ID="$(grep -Eo 'database_id = "[^"]+"' "$CREATE_LOG" | head -n1 | sed -E 's/.*"([^"]+)".*/\1/' || true)"
	if [[ -z "$DB_ID" ]]; then
		echo "Could not parse the D1 database ID from Wrangler output."
		rm -f "$CREATE_LOG"
		exit 1
	fi

	python3 - "$CFG_FILE" "$DB_ID" <<'PY'
import re
import sys

path, db_id = sys.argv[1], sys.argv[2]
with open(path, 'r', encoding='utf-8') as fh:
    text = fh.read()
text = re.sub(r'(database_id\s*=\s*)"[^"]*"', rf'\1"{db_id}"', text, count=1)
with open(path, 'w', encoding='utf-8') as fh:
    fh.write(text)
PY

	rm -f "$CREATE_LOG"
else
	echo "D1 database_id already set in config, skipping create."
fi

echo "Ensuring D1 schema exists..."
npx --yes wrangler d1 execute smart-care-sync \
	--remote \
	--file "$SCHEMA_FILE" \
	--config "$CFG_FILE"

DEPLOY_LOG="$(mktemp)"
echo "Deploying worker..."
if ! (cd "$CF_DIR" && npx --yes wrangler deploy --config "$CFG_FILE" | tee "$DEPLOY_LOG"); then
	echo "Deployment failed."
	exit 1
fi

WORKER_URL="$(grep -Eo 'https://[a-zA-Z0-9.-]+\.workers\.dev' "$DEPLOY_LOG" | tail -n1 || true)"
if [[ -z "$WORKER_URL" ]]; then
	echo "Could not parse workers.dev URL from deploy output."
	echo "Please check deploy output above."
	exit 1
fi

echo "Running sync API smoke test on $WORKER_URL/state ..."
SYNC_KEY="bootstrap-$(date +%s)"
POST_BODY='{"clients":[],"tasks":[],"records":[],"tokenShops":[],"tokenExchanges":[],"_meta":{"baseUpdatedAt":0,"lastSyncedAt":0,"deviceId":"bootstrap-script"}}'

POST_RESP="$(curl -sS -X POST "$WORKER_URL/state?key=$SYNC_KEY" -H 'content-type: application/json' --data "$POST_BODY")"
if [[ "$POST_RESP" != *'"ok":true'* ]]; then
	echo "POST smoke test failed: $POST_RESP"
	exit 1
fi

GET_RESP="$(curl -sS "$WORKER_URL/state?key=$SYNC_KEY")"
if [[ "$GET_RESP" != *'"ok":true'* || "$GET_RESP" != *'"value"'* ]]; then
	echo "GET smoke test failed: $GET_RESP"
	exit 1
fi

echo "Querying D1 for persisted rows..."
npx --yes wrangler d1 execute smart-care-sync \
	--remote \
	--command "SELECT sync_key, updated_at FROM sync_state ORDER BY updated_at DESC LIMIT 5;" \
	--config "$CFG_FILE"

echo "Done. Worker URL: $WORKER_URL/state"
