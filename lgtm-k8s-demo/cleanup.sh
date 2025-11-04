#!/bin/bash
set -euo pipefail

echo "🧹 Cleaning up LGTM Stack..."
echo ""

# Uninstall Helm releases
echo "📦 Removing Helm releases..."
helm uninstall python-app -n development 2>/dev/null && echo "  ✅ python-app removed" || echo "  ℹ️  python-app not found"
helm uninstall grafana -n monitoring 2>/dev/null && echo "  ✅ grafana removed" || echo "  ℹ️  grafana not found"
helm uninstall mimir -n monitoring 2>/dev/null && echo "  ✅ mimir removed" || echo "  ℹ️  mimir not found"
helm uninstall tempo -n monitoring 2>/dev/null && echo "  ✅ tempo removed" || echo "  ℹ️  tempo not found"
helm uninstall loki -n monitoring 2>/dev/null && echo "  ✅ loki removed" || echo "  ℹ️  loki not found"

echo ""
echo "🗑️  Deleting namespaces (this will remove PVCs)..."
kubectl delete namespace development --timeout=60s 2>/dev/null || echo "  ℹ️  development namespace not found"
kubectl delete namespace monitoring --timeout=60s 2>/dev/null || echo "  ℹ️  monitoring namespace not found"

echo ""
echo "🔧 Delete entire cluster?"
read -p "Delete Kind cluster 'lgtm-cluster'? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  kind delete cluster --name lgtm-cluster
  echo "  ✅ Cluster deleted"
else
  echo "  ℹ️  Cluster kept. Delete manually with: kind delete cluster --name lgtm-cluster"
fi

echo ""
echo "✅ Cleanup complete!"

