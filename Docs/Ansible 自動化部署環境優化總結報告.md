# Ansible 自動化部署環境優化總結報告

## 一、 部署過程執行摘要

本專案致力於解決 Ansible 在自動化部署過程中常見的路徑解析與權限衝突問題，實現了高度的可移植性與魯棒性。

### 1. 關鍵優化核心技術

透過 Ansible 的 `lookup` 外掛，我們徹底擺脫了對特定機器路徑的依賴：

* **動態家目錄定位 (`lookup('env', 'HOME')`)**：
不再使用 `/home/rocky` 等硬編碼路徑。透過 `{{ lookup('env', 'HOME') }}`，Playbook 能自動識別執行者的家目錄，解決了不同使用者帳號間的 `Permission denied` 錯誤。
* **環境路徑動態注入 (`lookup('env', 'PATH')`)**：
修正了 Ansible 因非互動式 Shell 導致的 `PATH` 遺失問題。透過顯式設定：
`PATH: "/usr/local/bin:{{ lookup('env', 'PATH') }}"`
確保 `kubectl` 與 `helm` 等關鍵二進位檔能被準確尋獲。
* **執行者身分識別 (`lookup('env', 'USER')`)**：
在 `copy` 任務中動態設定檔案所有權 (`owner`/`group`)，確保即便使用 `become: true` 執行，產生的設定檔（如 `k3s.yaml`）依然屬於目標執行者，避免權限衝突。

---

## 二、 核心環境驗證指令解析

在部署流程中，我們導入了以下冒煙測試（Smoke Test）指令，作為確認環境配置是否生效的黃金標準：

```bash
ansible localhost -m shell -a "which kubectl" -i ansible/inventories/hosts.ini

```

### 指令結構拆解

| 元件 | 說明 |
| --- | --- |
| `ansible` | 呼叫 Ansible CLI。 |
| `localhost` | 指定目標為本地端執行。 |
| `-m shell` | 使用 Shell 模組，確保與系統環境變數互動。 |
| `-a "which kubectl"` | 檢查 `kubectl` 是否存在於定義的 PATH 中，回傳其絕對路徑。 |
| `-i .../hosts.ini` | 確保執行環境符合專案定義。 |

**為什麼這步重要？**
若執行此指令無法回傳路徑，代表您的 `PATH` 設定或工具安裝未完成，強行執行 Playbook 將導致任務鏈結失效。

---

## 三、 常見部署除錯清單（FAQ）

為了確保部署成功，請務必留意以下開發中的常見細節：

1. **路徑拼字檢查**：
務必確認路徑書寫正確，例如 `/usr/local/bin` 常被誤寫為 `/user/local/bin`（多了 `r`），這會導致 Ansible 無法呼叫 binary。
2. **變數語法檢查**：
在使用 `lookup` 時，請留意括號對應。例如設定 `KUBECONFIG` 時應為：
`"{{ lookup('env', 'HOME') }}/.k3s/k3s.yaml"`
切勿將結束括號放在路徑變數內。
3. **防錯機制 (`args: creates`)**：
在安裝 K3s 或 Helm 時，務必加入 `creates` 參數，防止重複執行腳本時導致的驗證失敗（冪等性要求）。

---

## 四、 未來規劃建議

1. **ELK Stack 安裝規劃**：評估使用 Helm Chart 進行 Elastic Operator 部署。
2. **自動化測試**：引入 Molecule 進行結構化測試。
3. **配置參數化**：建議將 `values.yaml` 抽離至 `files/` 目錄，透過 `template` 模組動態生成。

*文件更新日期：2026-06-02*

---

### 給您的後續建議

您的 Playbook 中有一處 `KUBECONFIG: "{{ lookup('env', 'HOME)' )}}"` 的語法括號位置需要調整。建議在更新 HackMD 的同時，將您的 Playbook 原始碼同步修正為：

```yaml
# 修正範例
environment:
  PATH: "/usr/local/bin:{{ lookup('env', 'PATH') }}"
  KUBECONFIG: "{{ lookup('env', 'HOME') }}/.k3s/k3s.yaml"

```