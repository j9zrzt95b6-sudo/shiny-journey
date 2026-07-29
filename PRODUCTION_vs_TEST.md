🌐 生產環境 vs 本地測試環境
=============================

## 📍 兩個訪問方式對比

| 項目 | 生產環境（GitHub Pages） | 本地測試工具 |
|------|-------------------------|-----------|
| **URL** | https://j9zrzt95b6-sudo.github.io/shiny-journey/?syncKey=center-a | http://localhost:8000/sync-test.html |
| **用途** | 實際應用系統（Smart Care）| 跨裝置同步驗證工具 |
| **同步碼** | center-a（或自訂） | test-sync-2026 |
| **API** | Cloudflare Workers | 相同 API（可共用） |
| **後端健康檢查** | `./scripts/cloudflare-healthcheck.sh` | `./scripts/cloudflare-healthcheck.sh` |
| **推薦** | 生產使用 | 測試用 |

---

## 🚀 使用生產環境進行測試

### 方式 1：使用官方應用（推薦生產驗證）

#### 電腦端
```
打開：https://j9zrzt95b6-sudo.github.io/shiny-journey/?syncKey=center-a
設定：
  • 確認同步碼為 center-a
  • 確認 API 位址為 Cloudflare Workers
  • 新增個案並點「立即同步」
```

#### 手機端
```
打開：https://j9zrzt95b6-sudo.github.io/shiny-journey/?syncKey=center-a
操作：
  • 手機應自動使用相同同步碼
  • 點「立即同步」拉取最新資料
  • 驗證是否看到電腦新增的個案
```

**優點**：
- ✅ 使用實際應用系統
- ✅ 同步碼 center-a 已配置
- ✅ 自動讀取 URL 參數中的同步碼

---

### 方式 2：使用本地測試工具（推薦功能驗證）

#### 電腦端
```
打開：http://localhost:8000/sync-test.html
設定：
  • 同步碼：center-a（與生產保持一致）
  • API：https://smart-care-sync-api.j9zrzt95b6.workers.dev/state
  • 執行操作 → 推送到雲端
```

#### 手機端
```
打開：http://10.0.10.49:8000/sync-test.html
設定：
  • 同步碼：center-a（相同）
  • API：https://smart-care-sync-api.j9zrzt95b6.workers.dev/state
  • 拉取最新資料
```

**優點**：
- ✅ 明確的操作流程
- ✅ 詳細的日誌反饋
- ✅ 方便故障排除

---

## 🔄 跨系統同步測試

### 場景：電腦端用官方應用，手機端用測試工具

**可以！** 只要同步碼和 API 相同，任何裝置都能同步

#### 步驟
1. **電腦端**：打開官方應用
   ```
   https://j9zrzt95b6-sudo.github.io/shiny-journey/?syncKey=center-a
   新增個案並點「立即同步」
   ```

2. **手機端**：打開測試工具
   ```
   http://10.0.10.49:8000/sync-test.html
   同步碼：center-a
   API：https://smart-care-sync-api.j9zrzt95b6.workers.dev/state
   點「拉取最新資料」
   ```

3. **驗證**：手機本地資料表應顯示電腦新增的個案

---

## 🎯 推薦測試組合

### 完整驗證流程（最全面）

```
第一階段：本地測試工具
━━━━━━━━━━━━━━━━━
• 電腦：http://localhost:8000/sync-test.html
• 手機：http://10.0.10.49:8000/sync-test.html
• 同步碼：test-sync-2026
• 測試基本同步功能
• ✅ 確認無誤後進行第二階段

第二階段：生產環境官方應用
━━━━━━━━━━━━━━━━━
• 電腦：https://j9zrzt95b6-sudo.github.io/shiny-journey/?syncKey=center-a
• 手機：https://j9zrzt95b6-sudo.github.io/shiny-journey/?syncKey=center-a
• 同步碼：center-a
• 驗證生產環境功能正常

第三階段：混合測試（跨應用）
━━━━━━━━━━━━━━━━━
• 電腦：官方應用（生產環境）
• 手機：測試工具（本地工具）
• 同步碼：center-a（保持一致）
• 驗證跨應用是否能同步
```

---

## 📋 快速檢查清單

### 使用官方應用 (https://j9zrzt95b6-sudo.github.io/shiny-journey/?syncKey=center-a)

- [ ] 頁面能正常加載
- [ ] 同步碼自動顯示 center-a
- [ ] 可以新增個案
- [ ] 點「立即同步」後有確認訊息
- [ ] 刷新頁面後資料仍保留
- [ ] 手機端拉取後能看到電腦新增的資料

### 使用測試工具 (http://localhost:8000/sync-test.html)

- [ ] 兩端都能打開工具
- [ ] 同步碼和 API 設定相同
- [ ] 電腦端「執行操作」成功
- [ ] 電腦端「推送到雲端」成功（看到 ✅ 確認）
- [ ] 手機端「拉取最新資料」成功
- [ ] 手機本地資料表顯示個案數 > 0

---

## 🔗 所有訪問地址

### 生產環境（官方應用）
```
🌐 一般訪問
https://j9zrzt95b6-sudo.github.io/shiny-journey/

🌐 帶同步碼
https://j9zrzt95b6-sudo.github.io/shiny-journey/?syncKey=center-a

🌐 帶自訂同步碼
https://j9zrzt95b6-sudo.github.io/shiny-journey/?syncKey=YOUR-SYNC-KEY
```

### 本地開發環境（測試工具）
```
💻 電腦端
http://localhost:8000/sync-test.html

📱 手機端（替換 IP）
http://10.0.10.49:8000/sync-test.html
```

### 備用工具
```
💾 備份工具
http://localhost:8000/index.html

📋 官方版本
http://localhost:8000/official.html
```

---

## 💡 同步碼說明

### 什麼是同步碼？
同步碼是裝置間的識別符，相同的同步碼才能共享資料。

### 預設同步碼
- `center-a` - 測試中心 A
- `center-b` - 測試中心 B
- `smart-care-main` - 預設

### 自訂同步碼
```
官方應用 URL 中新增參數：
?syncKey=my-custom-key

或在應用內的設定中修改
```

### 同步碼規則
- 小寫字母、數字、底線、減號
- 最多 64 字元
- 例如：`classroom-1`, `teacher-001`, `test-2026-07-26`

---

## 🧪 測試建議

### 第一次測試（今天）
**推薦：使用官方應用**
```
1. 電腦打開：
   https://j9zrzt95b6-sudo.github.io/shiny-journey/?syncKey=center-a

2. 手機打開相同地址

3. 電腦新增個案 + 立即同步

4. 手機重整或點立即同步

5. 驗證：手機能看到電腦新增的資料嗎？
```

### 進階測試
**推薦：使用測試工具**
```
1. http://localhost:8000/sync-test.html

2. 電腦端執行操作 + 推送到雲端

3. 手機端拉取最新資料

4. 查看操作日誌詳細步驟
```

---

## ⚠️ 常見問題

### Q：我應該用官方應用還是測試工具？
**A**：
- 如果要驗證 **生產環境** 是否正常 → 用官方應用
- 如果要詳細了解 **同步流程** → 用測試工具
- 最好都試一遍

### Q：同步碼 center-a 從哪裡來？
**A**：您提供的 URL 中就有，是自動讀取的。也可以手動修改為其他值。

### Q：手機看不到電腦的資料怎麼辦？
**A**：
1. 確認同步碼完全相同
2. 確認 API 位址相同
3. 檢查瀏覽器開發者工具 (F12) 的 Network 頁籤
4. 查看是否有錯誤訊息

### Q：可以跨應用同步嗎（一個用官方應用，一個用測試工具）？
**A**：可以！只要同步碼和 API 相同即可，系統會自動同步。

---

**準備好了？選擇您的測試方式開始吧！** 🚀
