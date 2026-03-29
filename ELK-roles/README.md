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
# filebat 
[ELK Stack Tutorial](https://www.youtube.com/watch?v=GLGCJU4nR3M)

[ELK 部署流程](https://hackmd.io/@sam21/Hk6gpgBoZl)