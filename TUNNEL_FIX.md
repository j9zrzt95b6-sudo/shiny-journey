# Codespaces 轉送連線卡住排除

## 一鍵啟動
在終端執行：

```bash
./scripts/start-preview.sh 8001
```

腳本會自動：
- 找可用埠（8001 被占用就改 8002、8003...）
- 印出 Local URL 與 Forward URL
- 提示 Port 面板設定

啟動後用以下其中一種方式開啟：

1. 直接用 Ports 面板開啟 `8001`（推薦）
2. 連結格式：

```text
https://<CODESPACE_NAME>-8001.<GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN>
```

目前環境範例：

```text
https://shiny-journey-gx5qgw555qvxfvww7-8001.app.github.dev
```

## 如果一直顯示「正在連接到轉送連接埠」
1. 先登入同一個 GitHub 帳號
2. 在 VS Code `Ports` 面板找到腳本輸出的埠，設為 `Public`
3. 關閉舊分頁後，只開新的 Forward URL
4. 允許 `app.github.dev` Cookie（瀏覽器隱私設定）

## 快速健康檢查
容器內檢查服務是否正常：

```bash
curl -I http://127.0.0.1:8001
```

若回應 `200 OK`，代表網頁服務正常，問題在轉送驗證。

## 不走轉送的替代方式
可先在 VS Code 直接開 [index.html](index.html) 進行功能驗收。

## 目前常見根因
- 若 `curl -I http://127.0.0.1:埠號` 是 200，但瀏覽器卡住，通常是 tunnel 驗證或 cookie 問題，不是網頁程式問題。
