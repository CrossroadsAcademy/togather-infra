1. RUN
```bash
helm repo add betterstack-logs https://betterstackhq.github.io/logs-helm-chart
helm repo update
```

2. setup values.yaml with the token

3. deploy the logger with or without metrics server

```bash
helm install betterstack-logs betterstack-logs/betterstack-logs -f values.yaml \
  --set metrics-server.enabled=false
```
