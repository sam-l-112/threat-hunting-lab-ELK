## ELK helm 啟動
1. 
```bash
cd elk
```
2. 
```bash
helm install elasticsearch elastic/elasticsearch -f elasticsearch/values.yml
helm install filebeat elastic/filebeat -f filebeat/values.yml
helm install logstash elastic/logstash -f  logstash/values.yml
helm install kibana elastic/kibana -f kibana/values.yml
```
---
# ELK 資料
[yoyo-0-5ELK](https://github.com/Yoyo-0-5/ELK)

[yoyo-0-5filebeat](https://github.com/Yoyo-0-5/filebeat_yaml)

[ELK Stack Tutorial](https://www.youtube.com/watch?v=GLGCJU4nR3M)

---
# 部屬流程

[ELK 部署流程](https://hackmd.io/@sam21/Hk6gpgBoZl)
