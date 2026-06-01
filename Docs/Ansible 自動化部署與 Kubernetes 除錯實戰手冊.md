# Ansible 自動化部署與 Kubernetes 除錯實戰手冊

## 一、 部署過程執行摘要

本專案透過 Ansible 實現了 K3s 與 ELK Stack 的自動化部署，核心優化包含：

* **動態路徑解析**：使用 `lookup('env', 'HOME')` 與 `lookup('env', 'PATH')` 消除環境路徑依賴。
* **權限隔離**：透過環境變數注入 `KUBECONFIG`，確保跨權限執行的穩定性。
* **防錯機制**：引入 `args: creates` 確保 Playbook 具備冪等性，重複執行也不會導致安裝衝突。

---

## 二、 核心環境驗證與除錯指令

在確認叢集狀態時，我們使用以下指令進行即時監控與排查：

### 1. 叢集資源概覽 (冒煙測試)

當部署完成後，務必透過此指令檢查所有命名空間 (Namespace) 的 Pod 運行狀況：

```bash
kubectl get pods -A

```

* **Status 欄位說明**：
* `Running`：正常運作。
* `ContainerCreating` / `PodInitializing`：正在初始化（如下載映像檔）。
* `CrashLoopBackOff`：容器啟動後崩潰，請使用 `kubectl logs <pod_name>` 檢查。
* `Completed`：任務執行完畢（常見於 Helm 安裝任務）。



### 2. 環境路徑校準

確認 `kubectl` 指令路徑是否正確：

```bash
ansible localhost -m shell -a "which kubectl" -i ansible/inventories/hosts.ini

```

---

## 三、 密碼抓取與資源診斷 SOP

由於部署方式不同（Helm vs. Operator），存放密碼的 `Secret` 名稱與路徑會有差異。請依照以下流程診斷：

### 步驟 1：確認資源來源

首先確認叢集中是否存在 Elasticsearch 資源：

```bash
kubectl get elasticsearch -A

```

* **若無回傳值**：代表環境可能採用 **Helm Chart** 部署，請改為檢查 Helm Release。
* **若有回傳值**：代表使用 **ECK Operator** 部署。

### 步驟 2：獲取正確的 Secret 名稱

透過 `describe` 指令查看 Pod 的詳細配置，找出密碼存放位置：

```bash
# 查看 Pod 詳細資訊，尋找 Environment 區塊中的 Secret 名稱
kubectl describe pod <elasticsearch-pod-name> -n default

```

*(在輸出中搜尋 `ELASTIC_PASSWORD` 關鍵字，即可找到正確的 Secret 名稱)*

### 步驟 3：解碼並取得密碼

根據發現的 Secret 名稱執行以下指令：

* **若為 Helm 部署 (常見名稱: `elasticsearch-master-credentials`)**：

```bash
kubectl get secret <SECRET_NAME> -n default -o go-template='{{.data.password | base64decode}}'

```

* **若為 Operator 部署 (常見名稱: `...-es-elastic-user`)**：

```bash
kubectl get secret <SECRET_NAME> -n <NAMESPACE> -o go-template='{{.data.elastic | base64decode}}'

```

---

## 四、 觀念補充：Helm 與 Operator 的差異

* **Helm Chart**：將應用程式定義為一個「打包好的模板」，安裝後直接執行，適合標準化的部署。
* **Operator**：利用自定義控制迴圈 (Control Loop) 持續監控叢集狀態，並能自動處理升級、備份與自動修復，適合複雜的資料庫應用。

---

## 五、 FAQ 與排錯小教室

1. **顏色警示**：
* `黃色 (Changed)`：Ansible 對系統執行了實際變更（這是自動化成功的標誌）。
* `綠色 (Ok)`：系統已符合定義狀態。


2. **Path 拼字錯誤**：請務必注意 `/usr/local/bin`，常見錯誤是少寫了 `r`。
3. **Secret 找不到**：絕大多數是因為 Namespace 錯誤，務必加上 `-n <namespace>` 參數。

*文件更新日期：2026-06-02*

---

### 給您的建議

目前您的環境已經成功透過 Helm 部署了 ELK，這是一個非常穩定的架構。接下來您可以嘗試：

1. 將密碼透過 `kubectl port-forward` 進行登入測試。
2. 開始規劃 Logstash 的資料收集流程，將日誌從節點導入 Elasticsearch。
