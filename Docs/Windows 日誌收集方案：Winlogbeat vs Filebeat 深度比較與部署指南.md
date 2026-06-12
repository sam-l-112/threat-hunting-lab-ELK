# 📂 Windows 日誌收集方案：Winlogbeat vs Filebeat 深度比較與部署指南

在 Windows 環境中，將日誌（Logs）傳送到 ELK 架構最推薦的作法是使用 Elastic 官方的輕量化收集器（Beats 家族）。本篇針對專攻 Windows 系統事件的 **Winlogbeat** 與專攻文字檔的 **Filebeat** 進行深度分析與比較。

---

## 📊 一、核心功能與定位比較

| 比較項目 | Winlogbeat (系統守護者) | Filebeat (文字吞噬者) |
| :--- | :--- | :--- |
| **核心定位** | **專為 Windows 事件日誌系統** 設計 | **專為純文字日誌檔案（Text Files）** 設計 |
| **資料來源** | Windows 核心 **Event Log API**（不讀檔案） | 磁碟上的 **`.log`、`.txt`、`.json` 等實體檔案** |
| **適用場景** | 監控系統登入、帳號變更、資安威脅 (Sysmon) | 收集 IIS 網站、Tomcat、自研 API 的文字 Log |
| **跨平台支援**| ❌ **僅支援 Windows** |   **跨平台**（Windows, Linux, macOS） |
| **資料格式** | 原生 JSON 結構化輸出（免解析） | 純文字字串（需進 ELK 後利用 Grok/Dissect 拆解） |

---

## ⚙️ 二、架構運作原理

### 1. Winlogbeat 運作機制
Winlogbeat 直接向作業系統的事件日誌服務訂閱，當系統產生事件（如登入失敗）時，直接透過 API 撈取並轉為 JSON 送出。

```

[Windows Event Log 服務] ──(呼叫 Windows API)──> [Winlogbeat] ──> [ELK]

```

### 2. Filebeat 運作機制
Filebeat 扮演 `tail -f` 的角色，在硬碟中監控特定的資料夾路徑，紀錄檔案的指標（Offset），當有新的一行文字寫入時，將該行文字打包送出。

```

[應用程式] ──(寫入)──> [C:\logs\app.log 檔案] ──(監控 Offset)──> [Filebeat] ──> [ELK]

```

---

## 🛠️ 三、安裝與設定流程對比

兩者在 Windows 上的安裝指令有 90% 相同（皆為免安裝的綠色軟體），主要差異在於 `.yml` 設定檔的配置邏輯。

### 📋 共通部署四步驟 (PowerShell)
1. **下載解壓**：下載 ZIP 包並解壓至 `C:\Program Files\<Beat名稱>\`。
2. **修改設定**：配置目錄下的 `winlogbeat.yml` 或 `filebeat.yml`。
3. **註冊服務**：以系統管理員身分開啟 PowerShell 執行：
```powershell
   cd "C:\Program Files\<Beat名稱>"
   Powershell.exe -ExecutionPolicy Bypass -File .\install-service-<Beat名稱>.ps1

```

4. **啟動服務**：执行 `Start-Service <Beat名稱>`。

---

## ⚖️ 四、雙方優缺點（爽點與痛點）深度剖析

### 🟢 Winlogbeat

#### 方便的地方 (Pros)

* **隨開隨用**：日誌分類（Security, System）是作業系統標準化的，不需到處找檔案路徑。
* **原生精準過濾**：可以直接指定只收集特定 `event_id`。

```yaml
  winlogbeat.event_logs:
    - name: Security
      event_id: 4624, 4625 # 只抓登入成功與失敗，省頻寬與 ES 空間

```

* **資安整合度高**：原生支援微軟高階監控工具 `Sysmon`，免設定即可分析進程創建、網路連線等行為。

#### 不方便的地方 (Cons)

* **無法處理文字檔**：對本機硬碟裡的 `.log` 檔案完全無能為力。
* **客製化 Provider 名稱難查**：若有第三方軟體將 Log 寫入自定義的 Event Channel，必須去「事件檢視器」翻找精確的 Channel 完整名稱，設定較為繁瑣。

---

### 🔵 Filebeat

#### 方便的地方 (Pros)

* **路徑設定極具彈性**：支援萬用字元（Wildcards）與目錄遞迴搜尋。

```yaml
  paths:
    - C:\inetpub\logs\LogFiles\W3SVC1\*.log

```

* **內建開箱即用模組 (Modules)**：內建多種常見服務（如 IIS、Nginx、AWS）的解析原則與 Kibana 看板，一鍵即可啟用：

```powershell
  .\filebeat modules enable iis

```

#### 不方便的地方 (Cons)

* **多行日誌合併（Multiline）是大坑**：遇到 Java Stack Trace 或 帶換行的 Error Log，必須手寫複雜的「正則表達式（Regex）」進行合併，否則 Log 會在 Kibana 中碎成多筆，難以閱讀。
* **Windows 檔案鎖定衝突**：Windows 的檔案鎖定機制較嚴格。當 Filebeat 正在讀取、而應用程式剛好要進行日誌輪替（Log Rotate）時，偶爾會發生權限衝突（Permission Denied），需精細調校 `close_*` 相關參數。

---

## 💡 五、維運總結與實戰建議

:::success

### 📌 決策樹：我該怎麼選？

1. **我是 Windows 系統管理員 / 資安人員**
👉 **指名 Winlogbeat**。專門用來盯緊機器的帳號登入、系統錯誤與安全事件。
2. **我是 App 開發者 / 網站維運人員**
👉 **指名 Filebeat**。專門用來抓網頁（IIS）日誌、AP 拋出的文字 Log 檔。
3. **小孩子才做選擇，我全都要**
👉 **同時安裝**。這兩個 Beat 在 Windows 上各自獨立運行、互不干涉，且記憶體佔用極低（通常各幾十 MB），**在同一台伺服器上同時部署 Winlogbeat + Filebeat 是企業環境的標準常態。**
:::

```

### 💡 HackMD 使用小撇步：
1. 開啟 [HackMD](https://hackmd.io/) 並登入。
2. 點擊左上角的 **「New note（新增筆記）」**。
3. 切換到 **「Edit（編輯模式）」** 或 **「Both（雙欄模式）」**。
4. 將上面程式碼框格內的所有 Markdown 文字直接 **複製貼上**，就能完美呈現排版了！</Beat名稱></Beat名稱>