#!/bin/bash
set -euo pipefail

# LGTM Stack Deployment Script
# Usage: ./deploy.sh [dev|staging]

ENV="${1:-dev}"
CLUSTER_NAME="lgtm-cluster"

echo "LGTM Stack Deployment - Environment: $ENV"
echo "================================================"
echo ""

# ============================================================================
# STEP A: Check and install prerequisites on macOS
# ============================================================================
echo "STEP A: Checking prerequisites..."

check_and_install() {
  local tool=$1
  local install_cmd=$2
  
  if command -v "$tool" &> /dev/null; then
    echo "  [OK] $tool is installed"
  else
    echo "  [MISSING] $tool not found. Installing..."
    eval "$install_cmd"
    echo "  [OK] $tool installed"
  fi
}

# Check if running on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "  ℹ️  Detected macOS"
  
  # Check Homebrew
  if ! command -v brew &> /dev/null; then
    echo "  ❌ Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    echo "  ✅ Homebrew is installed"
  fi
  
  # Check and install tools
  check_and_install "docker" "brew install --cask docker && open -a Docker"
  check_and_install "kind" "brew install kind"
  check_and_install "kubectl" "brew install kubectl"
  check_and_install "helm" "brew install helm"
  
  # Wait for Docker to start
  if ! docker info &> /dev/null; then
    echo "  ⏳ Waiting for Docker to start..."
    for i in {1..30}; do
      if docker info &> /dev/null; then
        echo "  ✅ Docker is running"
        break
      fi
      sleep 2
    done
  fi
else
  echo "  ⚠️  Not macOS. Please ensure docker, kind, kubectl, helm are installed."
fi

echo ""

# ============================================================================
# STEP B: Create and check Kind cluster
# ============================================================================
echo "🔧 STEP B: Setting up Kind cluster..."

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "  ℹ️  Cluster '$CLUSTER_NAME' already exists"
else
  echo "  📦 Creating Kind cluster with NodePort mapping..."
  cat <<EOF | kind create cluster --name "$CLUSTER_NAME" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30000
    hostPort: 3000
    protocol: TCP
EOF
  echo "  ✅ Cluster created"
fi

# Wait for cluster to be ready
echo "  ⏳ Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=60s

# Create namespaces
echo "  📁 Creating namespaces..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace development --dry-run=client -o yaml | kubectl apply -f -

echo "  ✅ Cluster is ready"
echo ""

# ============================================================================
# STEP C: Deploy LGTM stack in monitoring namespace
# ============================================================================
echo "📊 STEP C: Deploying LGTM stack to 'monitoring' namespace..."

# Add Grafana Helm repo
echo "  📦 Adding Grafana Helm repository..."
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo update

# Pin versions
LOKI_VERSION="5.47.2"
TEMPO_VERSION="1.7.2"
MIMIR_VERSION="5.3.0"
GRAFANA_VERSION="7.3.7"
PROMETHEUS_VERSION="25.11.0"

echo ""
echo "  📌 Chart versions:"
echo "     - Loki: $LOKI_VERSION (retention: 30min)"
echo "     - Tempo: $TEMPO_VERSION"
echo "     - Mimir: $MIMIR_VERSION (retention: 30min)"
echo "     - Prometheus: $PROMETHEUS_VERSION (metric scraper)"
echo "     - Grafana: $GRAFANA_VERSION"
echo ""

# Deploy Loki
echo "  🪵  Deploying Loki..."
helm upgrade --install loki grafana/loki \
  --version "$LOKI_VERSION" \
  --namespace monitoring \
  --values "values/${ENV}/loki-values.yaml" \
  --wait --timeout 5m

# Deploy Tempo
echo "  🔍 Deploying Tempo..."
helm upgrade --install tempo grafana/tempo \
  --version "$TEMPO_VERSION" \
  --namespace monitoring \
  --values "values/${ENV}/tempo-values.yaml" \
  --wait --timeout 5m

# Deploy Mimir
echo "  📈 Deploying Mimir (this may take a few minutes)..."
helm upgrade --install mimir grafana/mimir-distributed \
  --version "$MIMIR_VERSION" \
  --namespace monitoring \
  --values "values/${ENV}/mimir-values.yaml" \
  --wait --timeout 10m

# Deploy Prometheus (for scraping metrics)
echo "  📊 Deploying Prometheus (metrics scraper)..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update
helm upgrade --install prometheus prometheus-community/prometheus \
  --version "$PROMETHEUS_VERSION" \
  --namespace monitoring \
  --values "values/${ENV}/prometheus-values.yaml" \
  --wait --timeout 5m

# Deploy Grafana
echo "  📊 Deploying Grafana..."
helm upgrade --install grafana grafana/grafana \
  --version "$GRAFANA_VERSION" \
  --namespace monitoring \
  --values "values/${ENV}/grafana-values.yaml" \
  --wait --timeout 5m

echo "  ✅ LGTM stack deployed"
echo ""

# ============================================================================
# STEP D: Deploy Python app in development namespace
# ============================================================================
echo "🐍 STEP D: Deploying Python application to 'development' namespace..."

# Build and load Docker image
echo "  🔨 Building Python app Docker image..."
docker build -t "lgtm-demo/python-app:${ENV}" . -q

echo "  📦 Loading image into Kind cluster..."
kind load docker-image "lgtm-demo/python-app:${ENV}" --name "$CLUSTER_NAME"

# Deploy app using Helm
echo "  🚀 Deploying Python app..."
helm upgrade --install python-app charts/python-app \
  --namespace development \
  --values "values/${ENV}/python-app-values.yaml" \
  --wait --timeout 3m

echo "  ✅ Python app deployed"
echo ""

# ============================================================================
# STEP E: Test if logs, metrics, traces are working
# ============================================================================
echo "🧪 STEP E: Testing LGTM stack..."

echo "  ⏳ Waiting for components to be fully ready..."
sleep 10

# Check all pods
echo ""
echo "  📋 Pod Status:"
kubectl get pods -n monitoring
kubectl get pods -n development
echo ""

# Test Loki
echo "  🪵  Testing Loki (logs)..."
LOKI_POD=$(kubectl get pod -n monitoring -l app.kubernetes.io/name=loki -o jsonpath='{.items[0].metadata.name}')
if kubectl exec -n monitoring "$LOKI_POD" -- wget -q -O- http://localhost:3100/ready | grep -q "ready"; then
  echo "     ✅ Loki is ready"
else
  echo "     ⚠️  Loki may not be fully ready yet"
fi

# Test Tempo
echo "  🔍 Testing Tempo (traces)..."
TEMPO_POD=$(kubectl get pod -n monitoring -l app.kubernetes.io/name=tempo -o jsonpath='{.items[0].metadata.name}')
if kubectl exec -n monitoring "$TEMPO_POD" -- wget -q -O- http://localhost:3100/ready 2>/dev/null; then
  echo "     ✅ Tempo is ready"
else
  echo "     ⚠️  Tempo may not be fully ready yet"
fi

# Test Mimir
echo "  📈 Testing Mimir (metrics)..."
if kubectl get svc -n monitoring mimir-nginx &>/dev/null; then
  echo "     ✅ Mimir services are running"
else
  echo "     ⚠️  Mimir may not be fully deployed yet"
fi

# Test Python app logs
echo "  🐍 Testing Python app (checking logs)..."
sleep 5
APP_LOGS=$(kubectl logs -n development -l app=python-app --tail=5 2>/dev/null || echo "")
if [[ -n "$APP_LOGS" ]]; then
  echo "     ✅ Python app is generating logs:"
  echo "$APP_LOGS" | sed 's/^/        /'
else
  echo "     ⚠️  No logs from Python app yet (may still be starting)"
fi

# Test if logs are reaching Loki
echo ""
echo "  🔗 Testing log ingestion to Loki..."
sleep 5
LOKI_QUERY=$(kubectl exec -n monitoring "$LOKI_POD" -- wget -q -O- 'http://localhost:3100/loki/api/v1/query?query={namespace="development"}' 2>/dev/null || echo '{"data":{"result":[]}}')
if echo "$LOKI_QUERY" | grep -q '"result":\['; then
  RESULT_COUNT=$(echo "$LOKI_QUERY" | grep -o '"result":\[[^]]*\]' | grep -o '\[' | wc -l | tr -d ' ')
  if [[ "$RESULT_COUNT" -gt 1 ]]; then
    echo "     ✅ Logs are being ingested into Loki"
  else
    echo "     ⚠️  Logs may not be reaching Loki yet (give it a minute)"
  fi
else
  echo "     ⚠️  Could not query Loki (it may still be initializing)"
fi

echo ""
echo "  ✅ Testing complete"
echo ""

# ============================================================================
# STEP F: Show endpoints and credentials
# ============================================================================
echo "🎉 STEP F: Deployment Summary"
echo "================================================"
echo ""
echo "📊 GRAFANA ACCESS:"
echo "  URL:      http://localhost:3000"
echo "  Username: admin"
if [[ "$ENV" == "staging" ]]; then
  echo "  Password: staging-pass"
else
  echo "  Password: admin"
fi
echo ""
echo "🔗 Services:"
echo "  - Loki (logs):    http://loki.monitoring.svc.cluster.local:3100"
echo "  - Tempo (traces): http://tempo.monitoring.svc.cluster.local:3100"
echo "  - Mimir (metrics): http://mimir-nginx.monitoring.svc.cluster.local:80/prometheus"
echo ""
echo "🐍 Python App:"
echo "  - Namespace: development"
echo "  - Replicas:  $(kubectl get deployment -n development python-app -o jsonpath='{.spec.replicas}')"
echo ""
echo "📝 Quick Commands:"
echo "  # View all pods"
echo "  kubectl get pods -n monitoring"
echo "  kubectl get pods -n development"
echo ""
echo "  # View Python app logs"
echo "  kubectl logs -n development -l app=python-app -f"
echo ""
echo "  # Access Grafana (already exposed via NodePort)"
echo "  open http://localhost:3000"
echo ""
echo "  # Query Loki from CLI"
echo "  kubectl exec -n monitoring $LOKI_POD -- wget -O- 'http://localhost:3100/loki/api/v1/query?query={namespace=\"development\"}'"
echo ""
echo "🧹 Cleanup:"
echo "  ./cleanup.sh"
echo ""
echo "✅ Deployment complete! Open Grafana and explore the LGTM Overview dashboard."

