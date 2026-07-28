#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

trim_input() {
  local raw="$1"
  raw="${raw%$'\r'}"
  raw="${raw##[[:space:]]}"
  raw="${raw%%[[:space:]]}"
  printf "%s" "$raw"
}

echo "[提示] 請在目前這個終端視窗輸入，不要切換到其他終端。"
echo "[提示] Token 輸入時不會顯示字元，屬於正常現象。"

if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
  echo "Cloudflare API Token 未設定。"
  while true; do
    read -rsp "請輸入 CLOUDFLARE_API_TOKEN: " CLOUDFLARE_API_TOKEN
    echo
    CLOUDFLARE_API_TOKEN="$(trim_input "$CLOUDFLARE_API_TOKEN")"
    if [[ -n "${CLOUDFLARE_API_TOKEN}" ]]; then
      if [[ "$CLOUDFLARE_API_TOKEN" != *"."* ]]; then
        echo "[警告] Token 格式看起來異常（通常會包含點號）。"
      fi
      echo "[OK] 已接收 Token（長度 ${#CLOUDFLARE_API_TOKEN}）"
      break
    fi
    echo "[錯誤] Token 不可為空，請重新輸入。"
  done
  export CLOUDFLARE_API_TOKEN
fi

if [[ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]]; then
  echo "Cloudflare Account ID 未設定。"
  while true; do
    read -rp "請輸入 CLOUDFLARE_ACCOUNT_ID: " CLOUDFLARE_ACCOUNT_ID
    CLOUDFLARE_ACCOUNT_ID="$(trim_input "$CLOUDFLARE_ACCOUNT_ID")"
    if [[ -n "${CLOUDFLARE_ACCOUNT_ID}" ]]; then
      if [[ ! "$CLOUDFLARE_ACCOUNT_ID" =~ ^[a-fA-F0-9]{32}$ ]]; then
        echo "[警告] Account ID 格式看起來異常（通常是 32 位十六進位）。"
      fi
      echo "[OK] 已接收 Account ID（長度 ${#CLOUDFLARE_ACCOUNT_ID}）"
      break
    fi
    echo "[錯誤] Account ID 不可為空，請重新輸入。"
  done
  export CLOUDFLARE_ACCOUNT_ID
fi

"$ROOT_DIR/scripts/cloudflare-d1-bootstrap.sh"
