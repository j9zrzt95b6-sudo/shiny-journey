#!/usr/bin/env node

/**
 * 跨裝置同步測試工具
 * 用途：自動化測試電腦端修改資料是否能在手機端同步
 * 
 * 使用方式：
 *   node sync-test.js --api <url> --key <syncKey>
 *   例如：node sync-test.js --api https://my-worker.workers.dev/state --key test-sync-2026
 */

const http = require('http');
const https = require('https');
const url = require('url');

// 彩色輸出
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m'
};

function log(color, label, message) {
  console.log(`${color}[${label}]${colors.reset} ${message}`);
}

function generateId() {
  return Math.random().toString(36).slice(2, 10);
}

function buildTestPayload(action = 'add', data = {}) {
  const timestamp = Date.now();
  return {
    classes: ["測試班級"],
    clients: [
      {
        id: generateId(),
        name: `測試個案_${action}_${timestamp}`,
        className: "測試班級",
        disability: "測試",
        ability: "A",
        goal: `同步測試 - ${action} 操作`,
        notes: `Created at ${new Date(timestamp).toISOString()}`,
        createdBy: "SyncTest",
        reinforcers: []
      }
    ],
    tasks: [],
    records: [],
    tokenShops: [],
    tokenExchanges: [],
    _meta: {
      updatedAt: timestamp,
      lastSyncedAt: timestamp,
      baseUpdatedAt: timestamp,
      localDirtyAt: 0,
      deviceId: "sync-test-device"
    },
    ...data
  };
}

async function makeRequest(apiUrl, method, body = null) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(apiUrl);
    const isHttps = urlObj.protocol === 'https:';
    const client = isHttps ? https : http;

    const options = {
      method,
      headers: {
        'Content-Type': 'application/json'
      }
    };

    const req = client.request(urlObj, options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve({
            status: res.statusCode,
            data: parsed,
            headers: res.headers
          });
        } catch (e) {
          resolve({
            status: res.statusCode,
            data: data,
            headers: res.headers
          });
        }
      });
    });

    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function testSyncEndpoint(apiUrl, syncKey) {
  log(colors.blue, 'INFO', `開始同步測試`);
  log(colors.blue, 'INFO', `API: ${apiUrl}`);
  log(colors.blue, 'INFO', `同步碼: ${syncKey}`);
  console.log('');

  const testUrl = `${apiUrl}?key=${encodeURIComponent(syncKey)}`;

  // 測試 1: GET 初始狀態
  log(colors.cyan, '測試 1', '讀取初始狀態 (GET)');
  try {
    const getRes = await makeRequest(testUrl, 'GET');
    log(colors.green, '✓ 狀態碼', `${getRes.status}`);
    const initialValue = getRes.data.value;
    log(colors.green, '✓ 回應', `${JSON.stringify(getRes.data).slice(0, 100)}...`);
    console.log('');

    // 測試 2: POST 新資料
    log(colors.cyan, '測試 2', '寫入新資料 (POST)');
    const newPayload = buildTestPayload('add');
    const postRes = await makeRequest(testUrl, 'POST', newPayload);
    
    if (postRes.status === 200 || postRes.status === 201) {
      log(colors.green, '✓ 寫入成功', `狀態碼 ${postRes.status}`);
      const serverUpdatedAt = postRes.data.updatedAt;
      log(colors.green, '✓ 服務端時間戳', `${serverUpdatedAt}`);
      console.log('');

      // 測試 3: GET 驗證已寫入
      log(colors.cyan, '測試 3', '驗證資料已寫入 (GET)');
      await new Promise(r => setTimeout(r, 500)); // 短暫等待
      
      const getRes2 = await makeRequest(testUrl, 'GET');
      if (getRes2.status === 200 && getRes2.data.value) {
        const savedData = getRes2.data.value;
        const hasClient = savedData.clients && savedData.clients.length > 0;
        
        if (hasClient) {
          log(colors.green, '✓ 資料已存入', `找到 ${savedData.clients.length} 個個案`);
          log(colors.green, '✓ 個案名稱', savedData.clients[0].name);
          console.log('');
        } else {
          log(colors.red, '✗ 驗證失敗', '未找到剛才寫入的個案');
          console.log('');
        }
      }

      // 測試 4: 修改資料
      log(colors.cyan, '測試 4', '修改已存在的資料 (POST 更新)');
      const modifiedPayload = buildTestPayload('modify');
      modifiedPayload._meta.baseUpdatedAt = serverUpdatedAt;
      modifiedPayload._meta.lastSyncedAt = serverUpdatedAt;
      
      const patchRes = await makeRequest(testUrl, 'POST', modifiedPayload);
      
      if (patchRes.status === 200) {
        log(colors.green, '✓ 修改成功', `新時間戳 ${patchRes.data.updatedAt}`);
        console.log('');
      } else if (patchRes.status === 409) {
        log(colors.yellow, '⚠ 版本衝突', `${patchRes.data.error}`);
        log(colors.yellow, '⚠ 伺服器版本', patchRes.data.serverUpdatedAt);
        console.log('');
      }

      // 測試 5: 測試版本控制 - 發送舊版本資料
      log(colors.cyan, '測試 5', '測試版本衝突處理 (故意發送舊版本)');
      const stalePayload = buildTestPayload('stale');
      stalePayload._meta.baseUpdatedAt = 1; // 非常舊的版本
      stalePayload._meta.lastSyncedAt = 1;
      
      const conflictRes = await makeRequest(testUrl, 'POST', stalePayload);
      
      if (conflictRes.status === 409) {
        log(colors.green, '✓ 正確識別版本衝突', `${conflictRes.data.error}`);
        log(colors.green, '✓ 伺服器當前版本', conflictRes.data.serverUpdatedAt);
      } else {
        log(colors.yellow, '⚠ 未預期狀態碼', `${conflictRes.status}`);
      }
      console.log('');

    } else if (postRes.status === 409) {
      log(colors.yellow, '⚠ 版本衝突（首次提交失敗）', postRes.data.error);
      console.log('');
    } else {
      log(colors.red, '✗ 寫入失敗', `狀態碼 ${postRes.status}: ${JSON.stringify(postRes.data)}`);
      console.log('');
    }

  } catch (err) {
    log(colors.red, '✗ 錯誤', err.message);
    console.log('');
  }

  // 測試 6: 網路延遲模擬
  log(colors.cyan, '測試 6', '模擬連續寫入（測試併發）');
  try {
    const payload1 = buildTestPayload('concurrent-1');
    const payload2 = buildTestPayload('concurrent-2');

    const res1 = await makeRequest(testUrl, 'POST', payload1);
    if (res1.status === 200) {
      log(colors.green, '✓ 第一次寫入', `成功`);
      
      // 立即進行第二次寫入（模擬快速連續編輯）
      payload2._meta.baseUpdatedAt = res1.data.updatedAt;
      const res2 = await makeRequest(testUrl, 'POST', payload2);
      
      if (res2.status === 200) {
        log(colors.green, '✓ 第二次寫入', `成功`);
      } else {
        log(colors.yellow, '⚠ 第二次寫入', `狀態碼 ${res2.status}`);
      }
    }
    console.log('');
  } catch (err) {
    log(colors.red, '✗ 併發測試失敗', err.message);
    console.log('');
  }

  // 測試摘要
  log(colors.green, '完成', '所有同步測試已執行');
  log(colors.blue, '提示', '請檢查:');
  log(colors.blue, '  1', '電腦端是否成功寫入資料');
  log(colors.blue, '  2', '手機端是否能通過 GET 讀取到寫入的資料');
  log(colors.blue, '  3', '版本衝突是否正確處理（409 狀態碼）');
}

// 解析命令列參數
const args = process.argv.slice(2);
let apiUrl = 'https://smart-care-sync.j9zrzt95b6.workers.dev/state';
let syncKey = 'test-sync-2026';

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--api' && args[i + 1]) {
    apiUrl = args[++i];
  } else if (args[i] === '--key' && args[i + 1]) {
    syncKey = args[++i];
  }
}

testSyncEndpoint(apiUrl, syncKey).catch(err => {
  log(colors.red, '致命錯誤', err.message);
  process.exit(1);
});
