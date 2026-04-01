# threat-hunting-lab-ELK

# 🛡️ Threat Hunting Lab: ELK 實戰偵測環境分析

## 📖 專案簡介 (Project Overview)
本實驗專案 [threat-hunting-lab-ELK](https://github.com/sam-l-112/threat-hunting-lab-ELK) 旨在建構一個端對端（End-to-End）的資安實驗室。透過 **Rocky Linux** 作為核心資安監控平台，結合 **Kali Linux** 模擬真實攻擊，驗證 ELK Stack 在處理資安日誌（Logs）時的過濾、分析與視覺化能力。

此環境是專為「藍隊（Blue Team）偵測訓練」與「資安威脅狩獵（Threat Hunting）」所設計的標準 SOC 實驗原型。

---

## 🏗️ 實驗室拓撲與元件 (Lab Topology)

| 角色 | 節點數量 | 作業系統 | 核心任務 |
| :--- | :--- | :--- | :--- |
| **SIEM 核心** | 1 | **Rocky Linux 9** | 運行 ELK Stack (Rocky-ELK-Forge)、日誌解析與告警 |
| **攻擊端** | 1 | **Kali Linux** | 執行 Nmap 掃描、Hydra 爆破、漏洞利用 (Metasploit) |
| **受控靶機** | 4 | **Win/Linux 混合** | 產生 OS 日誌、服務日誌、網路流量 (Beats 代理) |

---

## 📂 專案結構解析 (Repository Structure)

該 GitHub 專案的檔案佈局邏輯旨在實現「自動化部署」與「場景化偵測」：

### 1. 核心配置區 (Configuration & Rules)
* **`Logstash/`**: 包含 `.conf` 管道配置文件。負責將原始日誌（Raw Logs）透過 **Grok** 或 **Dissect** 插件轉換為結構化數據。
* **`Elasticsearch/`**: 包含索引映射（Mapping）與生命週期管理（ILM）策略，確保數據檢索效率。
* **`Kibana/`**: 提供預設的 Dashboard JSON 檔案，導入後即可直接觀察攻擊趨勢圖表。

### 2. 代理程式佈署 (Endpoint Agents)
* **`Beats/`**: 針對 4 台靶機的安裝腳本與 YAML 配置。
    * **Winlogbeat**: 擷取 Windows 事件檢視器 (Event ID 4624, 4688 等)。
    * **Auditbeat**: 監控 Linux 使用者行為與檔案完整性 (FIM)。
    * **Packetbeat**: 捕獲網路封包，偵測 Kali 的掃描行為。

### 3. 攻擊腳本與情境 (Simulation Scenarios)
* **`Attacks/`**: 存放 Kali Linux 執行的自動化攻擊指令（如 Python 腳本），用於驗證 ELK 是否能成功觸發告警並正確記錄攻擊者 IP。

---

## ⚙️ 技術運作邏輯 (Operational Logic)

本專案實作了完整的 **日誌生命週期**（Log Lifecycle）：

1.  **收集 (Collection)**：靶機上的 Beats 代理程式即時監控系統變動。
2.  **傳輸 (Transport)**：日誌透過安全通道傳送至 Rocky Linux 上的 Logstash (Port 5044)。
3.  **解析 (Parsing)**：Logstash 識別來自 Kali 的惡意特徵（例如：短時間內大量的登入失敗事件）。
4.  **存儲 (Storage)**：數據寫入 Elasticsearch 索引，並進行全文檢索優化。
5.  **視覺化 (Visualization)**：Kibana 儀表板呈現攻擊者的來源 IP、受攻擊最嚴重的靶機編號與攻擊時間軸。

---

## 🎯 實驗重點偵測目標
* **偵測掃描行為**：透過 Packetbeat 辨識 Nmap 的 SYN Scan 或進階隱蔽掃描。
* **偵測暴力破解**：監控 SSH/RDP 登入失敗頻率，自動觸發標籤（Tagging）。
* **偵測權限提升**：追蹤 Linux `sudo` 指令執行紀錄或 Windows 特權帳號變動。
* **偵測橫向移動**：分析不同靶機之間異常的內網連線行為（Lateral Movement）。

---

## 🔗 相關資源與來源
* **核心 OS 部署：** [Rocky ELK Forge](https://github.com/sam-l-112/Rocky-ELK-Forge) (基於 Rocky Linux 9)
* **部署流程參考：** [HackMD 詳細步驟](https://hackmd.io/@sam21/Hk6gpgBoZl)
* **專案倉庫：** [threat-hunting-lab-ELK](https://github.com/sam-l-112/threat-hunting-lab-ELK)

---
> [!NOTE]
> 專業建議：在 Rocky Linux 上運行此環境時，請務必確認 `SELinux` 的配置，建議在實驗初期將其設為 `Permissive` 模式，以確保日誌收集組件能順利與系統內核互動。

---
# 參考文件
[ELK 部署流程](https://hackmd.io/@sam21/Hk6gpgBoZl)

[CVE 漏洞資訊](https://hackmd.io/@sam21/r1BcalHoWe)

---

# 原生來源
## ELK Rocky 
[Rocky ELK Forge](https://github.com/sam-l-112/Rocky-ELK-Forge) 
