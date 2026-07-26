# Cloudflare 同步 API 設定（替代 Netlify）

## 1) 登入 Cloudflare

```bash
npx --yes wrangler login
```

## 2) 建立 KV namespace

```bash
npx --yes wrangler kv namespace create SMART_CARE_STATE
```

把輸出的 `id` 填入 [cloudflare/wrangler.toml.example](cloudflare/wrangler.toml.example)，另存為 `cloudflare/wrangler.toml`。

## 3) 部署 Worker

```bash
chmod +x scripts/deploy-cloudflare.sh
./scripts/deploy-cloudflare.sh
```

部署完成會得到 `https://<worker>.workers.dev`。

## 4) 在系統設定填入同步 API 位址

在系統的「跨裝置同步連結」區塊，設定：
- 同步 API 位址：`https://<worker>.workers.dev`
- 同步碼：例如 `center-a`

再按「套用同步碼」，並複製同步連結給其他裝置。

## 5) 驗證

1. A 裝置新增資料並同步
2. B 裝置開同一分享連結，應看到相同資料
3. C 裝置再修改，A/B 重新回到頁面應拿到最新版本

> 若遇到版本衝突，系統會自動回拉雲端最新資料，避免舊裝置覆蓋新資料。
