🎯 本地測試環境已就緒
========================

## ✅ 服務器狀態

本地 HTTP 服務器已啟動：
- 地址：http://localhost:8000
- 狀態：✅ 運行中
- 進程ID：見下方

## ☁️ Cloudflare 佈署與健康檢查（推薦）

```bash
cp .env.cloudflare.example .env.cloudflare
# 編輯 .env.cloudflare 填入 CLOUDFLARE_API_TOKEN / CLOUDFLARE_ACCOUNT_ID

chmod +x scripts/deploy-cloudflare.sh scripts/cloudflare-healthcheck.sh
./scripts/deploy-cloudflare.sh
./scripts/cloudflare-healthcheck.sh
```

若健康檢查回傳 storage 不是 d1，代表部署時可能使用了錯誤設定來源，請重新執行部署腳本。

## 🌐 前端重新部署（GitHub Pages）

```bash
git add -A
git commit -m "Update deploy workflows and sync docs"
git push origin main
```

GitHub Pages 會在 `main` 推送後自動重新部署；若你要保留本機預覽，仍可使用 `scripts/start-preview.sh`。

---

## 📱 訪問測試工具

### 方式 1：本機訪問
- 打開瀏覽器
- 輸入：http://localhost:8000/sync-test.html

### 方式 2：手機或平板訪問
1. 獲取電腦 IP 地址：
   ```bash
   hostname -I
   ```

2. 在手機瀏覽器輸入：
   ```
   http://<電腦IP>:8000/sync-test.html
   例如：http://192.168.1.100:8000/sync-test.html
   ```

### 方式 3：VS Code 內查看
- 按 Ctrl+Shift+P
- 輸入「Open with Live Server」
- 或使用 VS Code 中的 Preview 功能

---

## 🧪 快速驗證步驟

### 步驟 1：打開測試工具
```
http://localhost:8000/sync-test.html
```

### 步驟 2：配置同步參數
- 同步碼：test-sync-2026
- API 位址：https://smart-care-sync-api.j9zrzt95b6.workers.dev/state
   （或使用本地測試工具；正式後端以 Cloudflare Workers 為主）

### 步驟 3：檢查 API 連接
1. 點擊「檢查同步狀態」按鈕
2. 在操作日誌中查看結果：
   - ✅ 「API 連線正常」→ 後端可用
   - ❌ 「API 連線失敗」→ 檢查 API 地址和網路

### 步驟 4：執行測試
1. 切換到 💻 **電腦端**
2. 點擊「執行操作」（新增個案）
3. 查看日誌中的 ✓ 綠色確認訊息

### 步驟 5：驗證同步
1. 切換到 📱 **手機端**（可在另一個瀏覽器窗口/頁籤）
2. 點擊「拉取最新資料」
3. 檢查「手機本地資料」表格中的個案記錄數

---

## 📊 同步測試場景

### 場景 A：新增個案（最基礎）
```
電腦端：新增 → 手機端：拉取 → 驗證
```

### 場景 B：修改個案
```
1. 電腦：新增個案（確認已同步）
2. 電腦：修改個案備註
3. 手機：拉取最新資料
4. 手機：驗證備註是否已更新
```

### 場景 C：衝突測試
```
1. 電腦和手機同時修改同一個案
2. 觀察 API 返回 409 衝突
3. 驗證自動選用最新版本
```

---

## 🔍 故障排除

### 如果看到 「API 連線失敗」

1. **檢查 API 位址**
   - Cloudflare Workers：https://smart-care-sync-api.j9zrzt95b6.workers.dev/state
   - 若使用舊版本機測試，請確認 API 位址是否仍指向 Cloudflare Workers

2. **檢查網路連接**
   ```bash
   curl https://smart-care-sync-api.j9zrzt95b6.workers.dev/state?key=test
   ```

3. **檢查 CORS 設定**
   - 打開 DevTools (F12)
   - Network 頁籤查看回應頭

### 如果手機看不到電腦新增的資料

1. **確認同步碼相同**
   - 複製貼上而不是手打
   
2. **檢查 localStorage**
   - DevTools → Application → LocalStorage
   - 查看 `smart-care-state-v1` 是否有數據

3. **檢查 API 響應**
   - DevTools → Network → 查看 GET 請求
   - 檢查回應中是否包含電腦發送的數據

---

## 💡 開發者命令

在瀏覽器 Console (F12) 執行以快速檢查：

```javascript
// 查看本地數據
JSON.parse(localStorage.getItem('smart-care-state-v1'))

// 查看同步配置
JSON.parse(localStorage.getItem('sync-test-config'))

// 手動清空數據（謹慎！）
localStorage.clear()

// 查看最後同步時間
const state = JSON.parse(localStorage.getItem('smart-care-state-v1'));
new Date(state._meta?.updatedAt).toLocaleString('zh-TW')
```

---

## 📋 測試檢查清單

- [ ] API 連線正常（檢查同步狀態）
- [ ] 電腦端執行操作後顯示 ✓ 綠色確認
- [ ] 手機端拉取資料後個案數 > 0
- [ ] 電腦修改資料 → 手機拉取看到更新
- [ ] 連續多筆操作同時同步
- [ ] 網路中斷後恢復能重新同步

---

## 📞 需要幫助？

查看詳細指南：
- [QUICK_TEST.md](QUICK_TEST.md) - 快速 5 分鐘流程
- [SYNC_TEST.md](SYNC_TEST.md) - 完整測試場景和故障排除
- [TEST_CHECKLIST.md](TEST_CHECKLIST.md) - 驗收清單

---

**最後更新時間：2026-07-26**
**服務器狀態：✅ 運行中**
