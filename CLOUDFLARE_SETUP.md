# Cloudflare 同步 API 設定（免費資料庫版）

## 1) 登入 Cloudflare

```bash
npx --yes wrangler login
```

### Codespaces 常見問題：授權後跳到 localhost 無法連線

在 GitHub Codespaces / Dev Container 中，`wrangler login` 的 OAuth 回呼預設是 `http://localhost:8976/oauth/callback`。
授權頁在你本機瀏覽器開啟時，`localhost` 會指向你的本機，不是容器，因此常出現無法連線。

若遇到此問題，建議改用 API Token（不走 OAuth 回呼）：

1. 到 Cloudflare Dashboard 建立 API Token（建議權限）
	- Account: Account Settings Read
	- D1: Edit
	- Workers Scripts: Edit
	- Workers KV Storage: Edit（若要保留 KV 備援）
2. 在目前終端機設定環境變數（以下值請換成你的）

```bash
export CLOUDFLARE_API_TOKEN="<YOUR_API_TOKEN>"
export CLOUDFLARE_ACCOUNT_ID="<YOUR_ACCOUNT_ID>"
```

3. 驗證是否可用

```bash
npx --yes wrangler whoami
```

看到帳號資訊就可以直接執行後續 D1 建立與部署。

## 2) 建立 D1 資料庫（免費）

```bash
npx --yes wrangler d1 create smart-care-sync
```

把輸出的 `database_id` 填入 [cloudflare/wrangler.toml.example](cloudflare/wrangler.toml.example) 的 `[[d1_databases]]` 區塊，另存為 `cloudflare/wrangler.toml`。

## 3) （可選）建立 KV namespace 當備援

```bash
npx --yes wrangler kv namespace create SMART_CARE_STATE
```

把輸出的 `id` 填入 [cloudflare/wrangler.toml.example](cloudflare/wrangler.toml.example) 的 `[[kv_namespaces]]` 區塊。

> Worker 會優先使用 D1 資料庫；若未綁定 D1 才會退回 KV。

## 4) 部署 Worker

```bash
chmod +x scripts/deploy-cloudflare.sh
./scripts/deploy-cloudflare.sh
```

部署完成會得到 `https://<worker>.workers.dev`。

## 5) 在系統設定填入同步 API 位址

在系統的「跨裝置同步連結」區塊，設定：
- 同步 API 位址：`https://<worker>.workers.dev/state`
- 同步碼：例如 `center-a`

再按「套用同步碼」，並複製同步連結給其他裝置。

## 6) 驗證

1. A 裝置新增資料並同步
2. B 裝置開同一分享連結，應看到相同資料
3. C 裝置再修改，A/B 重新回到頁面應拿到最新版本

> 若遇到版本衝突，系統會自動回拉雲端最新資料，避免舊裝置覆蓋新資料。

## 7) 確認真的寫入資料庫

```bash
npx --yes wrangler d1 execute smart-care-sync --remote --command "SELECT sync_key, updated_at FROM sync_state ORDER BY updated_at DESC LIMIT 5;"
```

若看到資料列，表示跨裝置資料已持久化到 D1，不受單一裝置 localStorage 容量限制。
