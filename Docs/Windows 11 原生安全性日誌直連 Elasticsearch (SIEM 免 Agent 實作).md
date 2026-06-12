# Windows 11 原生安全性日誌直連 Elasticsearch (SIEM 免 Agent 實作)

---

## 📋 專案概述
本專案實作 Windows 11 環境下「免安裝輕量級 Agent（如 Winlogbeat）」的日誌收集架構。透過 Windows 內建的**工作排程器**結合 **PowerShell 腳本**，自動擷取最新的系統安全性日誌（以事件 ID 4624 登入成功為例），將其封裝為標準 JSON 格式，並透過安全加密連線（HTTPS + Basic Auth）直接推送至遠端的 Elasticsearch 叢集。

### 🏗️ 系統架構
> `Windows 11 事件檢視器 (Security)` ➡️ `PowerShell 腳本` ➡️ `工作排程器背景觸發` ➡️ `HTTPS (Basic Auth)` ➡️ `Elasticsearch (win11-logs 索引)` ➡️ `Kibana 視覺化`

---

## 🛠️ 第一階段：PowerShell 腳本部署

在 Windows 11 建立專用目錄 `C:\Scripts\`，並建立名為 **`send_to_es.ps1`** 的腳本檔案。

### 💾 最終完美版整合原始碼 (`send_to_es.ps1`)

```powershell
# ==============================================================================
# 腳本名稱：send_to_es.ps1
# 功能描述：擷取 Windows 11 最新安全性登入日誌並直接 POST 至 Elasticsearch
# ==============================================================================

# 1. 基礎設定（連線與認證資訊）
$ES_URL = "[https://172.16.1.4:9200/win11-logs/_doc](https://172.16.1.4:9200/win11-logs/_doc)"
$User   = "elastic"
$Pass   = "您的實際強密碼" # 請替換為實際 ES 密碼
$ErrorLogPath = "C:\Scripts\es_error.txt"

try {
    # 2. 安全通訊協定配置（啟用 TLS 1.2 並強制繞過自簽憑證檢查）
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

    # 3. 擷取最新一筆 Windows 安全性登入成功日誌 (Event ID: 4624)
    # 💡 注意：切勿加入不存在的參數（如 -EncounteredControls），以免腳本中斷
    $Event = Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4624} -MaxEvents 1

    if ($Event) {
        # 4. 轉換時區至標準 UTC 時間，格式化並封裝為 JSON 物件
        $LogBody = [PSCustomObject]@{
            "@timestamp"    = $Event.TimeCreated.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            "computer_name" = $Event.MachineName
            "event_id"      = $Event.Id
            "log_name"      = $Event.LogName
            "level"         = $Event.LevelDisplayName
            "message"       = $Event.Message
        } | ConvertTo-Json -Compress

        # 5. 建構 Basic Authentication 認證標頭
        $Pair = "$($User):$($Pass)"
        $Encoded = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($Pair))
        $Headers = @{ 
            "Content-Type"  = "application/json"
            "Authorization" = "Basic $Encoded"
        }

        # 6. 發射資料至 Elasticsearch
        $Response = Invoke-RestMethod -Uri $ES_URL -Method Post -Headers $Headers -Body ([System.Text.Encoding]::UTF8.GetBytes($LogBody))
    }
}
catch {
    # 錯誤攔截機制：若發生異常，自動寫入日誌檔以利排查
    $TimeStamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    "$TimeStamp - $($_.Exception.Message)" | Out-File -FilePath $ErrorLogPath -Append
}

```

---

## ⚙️ 第二階段：Windows 工作排程器自動化設定

為了達到免人工干預自動收集，需配置 Windows 工作排程器。

### 📝 設定步驟：

1. 開啟「工作排程器」，選擇 **建立工作**。
2. **一般頁籤**：
* 名稱輸入：`Send_Log_To_ES`
* 勾選 **「不論使用者登入與否均執行」**。
* 勾選 **「以最高權限執行」**（確保能讀取系統 Security 日誌）。


3. **觸發程序頁籤**：
* 依需求新增（如：當特定事件發生時、或是設定每 5 分鐘重複執行）。


4. **動作頁籤**（⚠️ **關鍵核心設定**）：
* 動作選擇：`啟動程式`
* **程式或指令碼**：
```text
powershell.exe

```


* **新增引數 (選擇性)**：（複製下方完整參數，確保背景隱藏且繞過資安原則限制）
```text
-WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Scripts\send_to_es.ps1"

```





---

## 📊 第三階段：Kibana Dev Tools 除錯與驗證指令

在 Kibana 的 **Management > Dev Tools (Console)** 中，使用以下指令進行資料生命週期管理與查詢：

### 1. 清理舊有結構（重建索引前必備）

```json
DELETE win11-logs

```

### 2. 檢查索引健康狀態與資料筆數 (Docs Count)

執行此指令確認 `docs.count` 是否破零、`store.size` 是否有正常增長。

```json
GET _cat/indices?v

```

### 3. 全量日誌查詢

```json
GET win11-logs/_search

```

### 4. 進階查詢：依時間戳記由新到舊排序 (Sort by Timestamp)

```json
GET win11-logs/_search
{
  "size": 10,
  "sort": [
    {
      "@timestamp": {
        "order": "desc"
      }
    }
  ]
}

```

---

## 🚨 🩸 經典踩坑與血淚除錯紀錄 (Troubleshooting)

在專案通關過程中，團隊陸續擊破了 5 個極具價值的技術地雷：

### Bug 1：PowerShell 權限遭全域資安原則阻擋 (`ExecutionPolicy`)

* **現象**：手動執行指令碼時，拋出資安原則不允許執行的錯誤。
* **解法**：在工作排程器或手動測試時，強制加入 **`-ExecutionPolicy Bypass`** 參數，暫時繞過限制，且不破壞系統既有安全設定。

### Bug 2：微軟預設字型造成的視覺陷阱 (11 vs ll)

* **現象**：Kibana 持續噴出 `404 - Index Not Found`。
* **原因**：肉眼將 `win11-logs`（數字 11）看錯成 `WINll-logs`（小寫英文字母 LL），因字型極度相似導致打錯查詢指令。

### Bug 3：隱藏版 HTTPS 通訊協定與 401 驗證

* **現象**：使用 `http://` 連線時，PowerShell 瘋狂報錯 **`基礎連接已關閉: 連接意外關閉`**。
* **原因**：底層 Elasticsearch 實則啟用了 HTTPS 憑證加密與帳密保護。當非加密請求撞擊加密 Port 時會被直接中斷。
* **解法**：將連線協定改為 `https://`，並在 PowerShell 中加入 `[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }` 繞過自簽憑證檢查，並實作 Base64 密碼標頭認證。

### Bug 4：無效的網路複製參數錯誤 (`EncounteredControls`)

* **現象**：`es_error.txt` 出現 `找不到符合參數名稱 'EncounteredControls' 的參數`。
* **原因**：`Get-WinEvent` 被誤塞了作業系統不認得的幽靈參數，導致腳本在第一步就陣亡。將其修剪回標準原生參數後即恢復正常。

### Bug 5：時區錯置導致 Kibana 無法映射排序 (`400 Bad Request`)

* **現象**：排序時噴出 `No mapping found for [@timestamp] in order to sort on`。
* **原因**：Windows 撈出的時間為台灣本地時間 (UTC+8)，若強加 `Z` 會導致 ELK 判斷時間錯亂。改用 `.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")` 將時間標準化為 UTC 零時區，即可在 Kibana 完美排序。