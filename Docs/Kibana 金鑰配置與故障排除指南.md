# 🛡️ K3s ELK 威脅獵捕實驗室：Kibana 金鑰配置與故障排除指南

:::info
- **專案名稱：** `threat-hunting-lab-ELK`
- **環境：** K3s (Kubernetes v1.26+)
- **組件：** Elasticsearch 8.5.1 / Kibana 8.5.1
- **負責人：** 廖柏煒
:::

---

[TOC]

---

## 📌 概述
本文件記錄了在 K3s 環境下，如何為 Kibana 生成並配置必要的加密金鑰（Encryption Keys）、解決因 `--no-hooks` 強制升級導致的 Service Account Token 認證故障，以及如何安全地向啟用 Security 的 Elasticsearch 叢集注入測試日誌。

---

## 🔑 一、 Kibana 加密金鑰生成與配置

當 Kibana 需要啟用安全模組、自動告警（Alerting）或報表（Reporting）功能時，必須在後台配置三組長度大於 32 個字元的加密金鑰。

### 1. 線上生成金鑰
由於 Kibana 運行在 K3s Pod 中，直接透過 `kubectl exec` 進入目前運行的 Pod 內執行官方生成工具：
```bash
kubectl exec -it kibana-kibana-546b7c779-tbx95 -n default -- /usr/share/kibana/bin/kibana-encryption-keys generate

```

> ⚠️ **執行後會輸出类似以下的內容，請先複製備用：**
> `xpack.encryptedSavedObjects.encryptionKey: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
> `xpack.reporting.encryptionKey: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
> `xpack.security.encryptionKey: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

[Alerts簡介](https://ithelp.ithome.com.tw/articles/10274682)

[Alerting](https://www.elastic.co/docs/explore-analyze/alerting)


### 2. 修改 Helm `values.yml`

請勿直接修改容器內的 `kibana.yml`（Pod 重啟後變更會遺失）。
請打開專案路徑 `threat-hunting-lab-ELK/ELK-roles/kibana/values.yml`，定位至 `extraEnvs` 區段，將金鑰以環境變數形式注入：

```yaml
extraEnvs:
  - name: "NODE_OPTIONS"
    value: "--max-old-space-size=1800"
  - name: "XPACK_ENCRYPTEDSAVEDOBJECTS_ENCRYPTIONKEY"
    value: "你的第一組金鑰字串"
  - name: "XPACK_REPORTING_ENCRYPTIONKEY"
    value: "你的第二組金鑰字串"
  - name: "XPACK_SECURITY_ENCRYPTIONKEY"
    value: "你的第三組金鑰字串"

```

### 3. 清理殘留 Hook Job 並強制升級

若 Helm 升級時因 `pre-install-kibana-kibana` 任務超時（Timeout）卡死，請先手動清理殘留資源，並帶上 `--no-hooks` 參數強制套用變更：

```bash
# 1. 清除卡住且不斷噴 Error 的 pre-install 任務
kubectl delete job pre-install-kibana-kibana -n default

# 2. 切換至專案目錄並強制升級 Helm Release
cd threat-hunting-lab-ELK/ELK-roles/
helm upgrade kibana elastic/kibana -f kibana/values.yml -n default --no-hooks
```

```bash=
# 啟動 
helm upgrade kibana elastic/kibana -f values.yml -n default --no-hooks
```

### 4. 驗證金鑰注入狀態

等待新 Pod 重啟完成（狀態顯示為 `1/1 Running`）後，驗證環境變數是否成功吃進容器：

```bash
# 查看新舊 Pod 交接狀態
kubectl get pods -n default

# 檢查新 Pod 內部的環境變數
kubectl exec -it kibana-kibana-cfcc6dc44-bdrbc -n default -- env | grep ENCRYPTIONKEY

```

---

## 🛠️ 二、 修正 Service Account Token 認證錯誤

若網頁持續顯示 `Kibana server is not ready yet`，且 Log 噴出 `failed to authenticate service account [elastic/kibana]`，代表兩者間的連線憑證/Token 已失效，需手動重置。

### 1. 重新生成 Elasticsearch 服務 Token

進到 Elasticsearch 主節點容器中，為 Kibana 重新簽發一組安全連線 Token：

```bash
kubectl exec -it elasticsearch-master-0 -n default -- bin/elasticsearch-service-tokens create elastic/kibana kibana-kibana

```

*請完整複製畫面上產生的 `AAEAAWVsYXN0aWM...` 長字串。*

### 2. 強制更新 K3s Secret 物件

利用 `kubectl` 意圖宣告（Dry-run）機制，直接線上強制覆蓋 Kibana 讀取的 Token 憑證（將下方代碼中 `【你的新Token】` 替換）：

```bash
kubectl create secret generic kibana-kibana-es-token \
  --from-literal=token="【你的新Token】" \
  -n default \
  --dry-run=client -o yaml | kubectl apply -f -

```

### 3. 重啟 Kibana Pod 並追蹤日誌

```bash
# 刪除舊 Pod 觸發 Deployment 自動重構
kubectl delete pod kibana-kibana-cfcc6dc44-bdrbc -n default

# 即時監控 Kibana 後台初始化狀態
kubectl logs -l release=kibana -n default --tail=50 -f

```

:::success
當日誌出現 `[INFO ][server] http server running` 且無錯誤時，代表 Kibana 已成功解鎖！
:::

---

## 🎯 三、 Elasticsearch 數據注入測試 (以 OpenCVE 為例)

基礎建設完成後，可透過 `curl` 模擬發送黑客攻擊日誌或威脅情報至 Elasticsearch。

:::warning
由於叢集開啟了 **X-Pack Security** 安全模組，任何 REST API 請求皆必須使用 `-u` 參數帶上憑證，否則會觸發 `security_exception` (401 Unauthorized)。
:::

### 1. 使用 HTTP Basic Auth 注入單筆 Log

透過 `kubectl exec` 呼叫容器內的 `curl` 對內部 9200 埠發送加密請求（請將 `你的密碼` 自行替換）：

```bash
kubectl exec -it elasticsearch-master-0 -- curl -k -u "elastic:你的密碼" \
  -X POST "https://localhost:9200/opencve-data-2026.06.03/_doc/1" \
  -H 'Content-Type: application/json' \
  -d '{"message": "Test log from OpenCVE"}'

```

### 2. 參數解析

* `-k` (或 `--insecure`)：允許連線至自簽發憑證（Self-signed SSL）的 HTTPS 節點。
* `-u "username:password"`：傳遞基礎認證憑證，破解 `missing authentication credentials` 報錯。
* `_doc/1`：於 `opencve-data-2026.06.03` 索引中指定建立 ID 為 1 的文檔。


---
# 問件參考

[Alerting and action settings in Kibana](https://www.elastic.co/guide/en/kibana/8.5/alert-action-settings-kb.html#general-alert-action-settings)

[設定Alerts](https://ithelp.ithome.com.tw/articles/10273942)

[建立一個監控條件，並將告警存入Index ](https://jovepater.com/article/elk-lesson-28-alerting-index/)

[Create and manage rules](https://www.elastic.co/guide/en/kibana/8.19/create-and-manage-rules.html#defining-rules-actions-details)

[Create and manage rules](https://www.elastic.co/guide/en/kibana/8.5/create-and-manage-rules.html)

[Create a log threshold rule](https://www.elastic.co/docs/solutions/observability/incident-management/create-log-threshold-rule)

[Create a log threshold rule](https://www.elastic.co/docs/solutions/observability/incident-management/create-log-threshold-rule)

[有效的使用 Observability 的資料 (2) - 使用 Kibana Alerts 主動通知異常狀況](https://ithelp.ithome.com.tw/articles/10281084)

[github elastic](https://github.com/elastic)