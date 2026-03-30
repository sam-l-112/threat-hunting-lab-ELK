# threat-hunting-lab-ELK

# Rocky ELK Forge：資安威脅狩獵實驗室部署指南

## 專案概述

本文件說明如何在 Rocky Linux 9 上部署 ELK Stack (Elasticsearch, Logstash, Kibana)。此環境將作為「資安威脅狩獵實驗室」的核心 SIEM（安全資訊與事件管理）系統，負責接收來自四台靶機的日誌，並監控來自 Kali Linux 的攻擊行為。

|組件 | 作業系統 / 平台 | 角色描述 |
| :--- | :--- | :--- | 
| SIEM 核心 | Rocky Linux 9 | 運行 ELK Stack (Rocky-ELK-Forge)|
|攻擊端 | Kali Linux | 執行滲透測試與攻擊模擬 | 
|受控靶機 (x4) | Windows / Linux 混合 | 提供日誌遙測數據 (Beats / Syslog) |

---
# Rocky ELK 節點規格建議

CPU: 至少 4 vCPUs

記憶體: 8GB - 16GB (需針對 JVM Heap 進行優化)

儲存空間: 50GB+ SSD (建議使用 XFS 檔案系統)

網路: 設定靜態 IP (Static IP)

---

# 組件,作業系統 / 平台,角色描述

SIEM 核心,Rocky Linux 9,運行 ELK Stack (Rocky-ELK-Forge)

攻擊端,Kali Linux,執行滲透測試與攻擊模擬

受控靶機 (x4),Windows / Linux 混合,提供日誌遙測數據 (Beats / Syslog)

---
# 部署流程
1. 環境初始化

在安裝 ELK 之前，必須先針對 Rocky Linux 進行系統級優化，以符合 Elasticsearch 的高運作需求。

```bash
# 更新系統並安裝基礎依賴
sudo dnf update -y
sudo dnf install -y java-17-openjdk-devel wget vim

# 停用 Swap 以防止效能大幅下降
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 優化 Elasticsearch 的虛擬記憶體限制
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

2. 配置 Elastic 官方軟體源

使用官方 Yum 儲存庫以確保獲取經過簽署且穩定的最新版本。

```bash
sudo rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch

# 建立 repo 檔案
cat <<EOF | sudo tee /etc/yum.repos.d/elasticsearch.repo
[elasticsearch]
name=Elasticsearch repository for 8.x packages
baseurl=https://artifacts.elastic.co/packages/8.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOF
```

3. 安裝與啟動服務

安裝核心組件。在此實驗中，Logstash 扮演關鍵角色，負責解析來自 Kali 攻擊流量的複雜日誌。

```bash
sudo dnf install elasticsearch kibana logstash -y

# 設定服務開機自動啟動並立即運行
sudo systemctl daemon-reload
sudo systemctl enable --now elasticsearch kibana logstash
```

---
# 參考文件
[ELK 部署流程](https://hackmd.io/@sam21/Hk6gpgBoZl)
[ELK 部署流程](https://hackmd.io/@sam21/Hk6gpgBoZl)

---

# 主要來源
## ELK Rocky 
[Rocky ELK Forge](https://github.com/sam-l-112/Rocky-ELK-Forge) 