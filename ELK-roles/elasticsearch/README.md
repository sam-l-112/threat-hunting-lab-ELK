# elasticsearch 密碼獲取
- 在 Helm 中，你可能需要自己管理密碼。在 ECK 中，它會自動為 elastic 用戶生成隨機密碼並存存在 Secret 中。

```bash
kubectl get secret quickstart-es-elastic-user -o go-template='{{.data.elastic | base64decode}}'
```