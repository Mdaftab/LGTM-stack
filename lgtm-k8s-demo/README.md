# LGTM Stack on Kubernetes

Complete observability stack using **official Grafana Helm charts** with dev and staging environments.

## 🎯 What's Inside

- **Loki** - Log aggregation
- **Grafana** - Visualization and dashboards  
- **Tempo** - Distributed tracing
- **Mimir** - Metrics (Prometheus compatible)
- **Python App** - Log generator for testing

## 🏗️ Architecture

```
┌─────────────────────────────────────┐
│     Namespace: monitoring           │
│  ┌───────┐ ┌───────┐ ┌──────────┐  │
│  │ Loki  │ │ Tempo │ │  Mimir   │  │
│  └───▲───┘ └───▲───┘ └────▲─────┘  │
│      │         │          │         │
│      └─────────┴──────────┘         │
│              │                      │
│        ┌─────▼─────┐                │
│        │  Grafana  │                │
│        └───────────┘                │
└─────────────────────────────────────┘
               ▲
               │ logs, metrics, traces
               │
┌──────────────┴──────────────────────┐
│     Namespace: development          │
│       ┌────────────────┐            │
│       │  Python App    │            │
│       └────────────────┘            │
└─────────────────────────────────────┘
```

## 🚀 Quick Start

### Deploy Dev Environment

```bash
chmod +x deploy.sh cleanup.sh
./deploy.sh dev
```

### Deploy Staging Environment

```bash
./deploy.sh staging
```

The script will:
1. ✅ Check and install prerequisites (macOS)
2. ✅ Create Kind cluster
3. ✅ Deploy LGTM stack to `monitoring` namespace
4. ✅ Deploy Python app to `development` namespace  
5. ✅ Test logs/metrics/traces
6. ✅ Show Grafana access info

## 📊 Access Grafana

After deployment:

```
URL:      http://localhost:3000
Username: admin
Password: admin (dev) or staging-pass (staging)
```

## 📂 Project Structure

```
lgtm-k8s-demo/
├── values/
│   ├── dev/              # Dev environment values
│   │   ├── grafana-values.yaml
│   │   ├── loki-values.yaml
│   │   ├── tempo-values.yaml
│   │   ├── mimir-values.yaml
│   │   └── python-app-values.yaml
│   └── staging/          # Staging environment values
│       ├── grafana-values.yaml
│       ├── loki-values.yaml
│       ├── tempo-values.yaml
│       ├── mimir-values.yaml
│       └── python-app-values.yaml
├── charts/
│   └── python-app/       # Python app Helm chart
├── app.py                # Python log generator
├── Dockerfile
├── deploy.sh             # Main deployment script
├── cleanup.sh            # Cleanup script
└── README.md
```

## 📋 Requirements

**macOS** (auto-installed by deploy.sh):
- Homebrew
- Docker Desktop
- Kind
- kubectl
- Helm

**Other OS**: Install above tools manually

## 🎨 Official Charts Used

| Component | Chart | Version |
|-----------|-------|---------|
| Loki | grafana/loki | 5.47.2 |
| Tempo | grafana/tempo | 1.7.2 |
| Mimir | grafana/mimir-distributed | 5.3.0 |
| Grafana | grafana/grafana | 7.3.7 |

## 🔍 Verify Deployment

```bash
# Check pods
kubectl get pods -n monitoring
kubectl get pods -n development

# View app logs
kubectl logs -n development -l app=python-app -f

# Query Loki
kubectl exec -n monitoring <loki-pod> -- \
  wget -O- 'http://localhost:3100/loki/api/v1/query?query={namespace="development"}'
```

## 🧪 Test in Grafana

1. Open http://localhost:3000
2. Go to **Explore**
3. Select **Loki** datasource
4. Query: `{namespace="development"}`
5. See real-time logs from Python app

Or view the pre-provisioned **LGTM Overview** dashboard.

## 🗑️ Cleanup

```bash
./cleanup.sh
```

This removes:
- Helm releases
- Namespaces (including PVCs)
- Optionally: Kind cluster

## 🔄 Switch Environments

### Dev → Staging
```bash
./deploy.sh staging
```

**Changes**:
- Grafana password: `admin` → `staging-pass`
- Python app replicas: 1 → 2
- Dashboard title: "DEV" → "STAGING"

## 📝 Customization

Edit values files:
- `values/dev/*.yaml` - Dev configuration
- `values/staging/*.yaml` - Staging configuration

Then redeploy:
```bash
./deploy.sh dev
```

## 🛠️ Troubleshooting

### Pods not starting
```bash
kubectl describe pod <pod-name> -n monitoring
kubectl logs <pod-name> -n monitoring
```

### Docker not running
```bash
open -a Docker  # macOS
```

### Reinstall component
```bash
helm uninstall <component> -n monitoring
./deploy.sh dev
```

## 📚 Resources

- [Grafana](https://grafana.com/docs/)
- [Loki](https://grafana.com/docs/loki/)
- [Tempo](https://grafana.com/docs/tempo/)
- [Mimir](https://grafana.com/docs/mimir/)
- [Helm Charts](https://github.com/grafana/helm-charts)

## 📄 License

MIT
