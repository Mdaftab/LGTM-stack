# LGTM Stack - Quick Start Guide

## ⚡ 1-Command Deploy

```bash
./deploy.sh dev
```

That's it! The script handles everything automatically.

## 🎯 What Happens

1. ✅ Checks/installs: Docker, Kind, kubectl, Helm (macOS)
2. ✅ Creates Kind cluster with NodePort for Grafana
3. ✅ Creates namespaces: `monitoring`, `development`
4. ✅ Deploys official Helm charts:
   - Loki 5.47.2 (logs)
   - Tempo 1.7.2 (traces)
   - Mimir 5.3.0 (metrics)
   - Grafana 7.3.7 (dashboards)
5. ✅ Builds and deploys Python log generator
6. ✅ Tests log ingestion
7. ✅ Shows access credentials

## 📊 Access Grafana

```
http://localhost:3000
Username: admin
Password: admin
```

## 🔍 View Logs

In Grafana:
1. Click **Explore** (compass icon)
2. Select **Loki** datasource
3. Query: `{namespace="development"}`
4. See real-time logs!

## 📈 View Metrics

1. Select **Prometheus** datasource
2. Query: `sum(rate(generated_logs_total[5m])) by (level)`
3. See log rates by level!

## 🎨 View Dashboard

Go to: **Dashboards → LGTM Overview - DEV**

## 🔄 Deploy Staging

```bash
./deploy.sh staging
```

**Differences from dev:**
- Password: `staging-pass`
- Python app: 2 replicas (vs 1)
- Dashboard: "STAGING" label

## 🧹 Cleanup

```bash
./cleanup.sh
```

Removes everything (prompts before deleting cluster).

## 📝 Useful Commands

```bash
# Check pod status
kubectl get pods -n monitoring
kubectl get pods -n development

# View Python app logs
kubectl logs -n development -l app=python-app -f

# Check Helm releases
helm list -n monitoring
helm list -n development

# Port-forward if NodePort doesn't work
kubectl port-forward -n monitoring svc/grafana 3000:80
```

## 🆘 Troubleshooting

### "Docker not running"
```bash
open -a Docker  # macOS
# Wait 30 seconds, then re-run deploy.sh
```

### "Command not found"
Run deploy.sh again - it will install missing tools.

### "Pods not ready"
```bash
kubectl get pods -n monitoring
# Wait a few minutes for large components (Mimir)
```

### Start fresh
```bash
./cleanup.sh  # Say 'y' to delete cluster
./deploy.sh dev
```

## 🎓 Learn More

- **README.md** - Full documentation
- **values/dev/** - Configuration files
- **Official docs**: https://grafana.com/docs/

---

**Ready?** Run `./deploy.sh dev` and open http://localhost:3000 🚀

