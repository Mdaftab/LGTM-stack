# LGTM Stack - Testing Guide

## 🎯 Quick Access

```
URL:      http://localhost:3000
Username: admin
Password: admin (dev) or staging-pass (staging)
```

## 📊 What's Being Generated

The Python app generates realistic logs and metrics:

### Logs
- **INFO**: User actions (created, updated, deleted, fetched resources)
- **WARNING**: Slow queries (2-5 seconds)
- **ERROR**: Database timeouts, rate limits, service errors

### Users
- alice, bob, charlie, diana, eve

### Endpoints
- `/api/users`
- `/api/orders`
- `/api/products`
- `/api/health`
- `/api/login`

### Metrics
1. **generated_logs_total** (Counter)
   - Labels: level, environment
   - Total log lines generated

2. **http_request_duration_seconds** (Histogram)
   - Labels: method, endpoint
   - Request duration distribution

3. **active_connections** (Gauge)
   - Labels: environment
   - Simulated active connections (5-50)

## 🔍 Testing Logs (Loki)

### Access Explore
1. Click the **Explore** icon (compass) in left sidebar
2. Select **Loki** from dropdown

### Basic Queries

**All logs from app:**
```logql
{app="python-app", namespace="development"}
```

**Only errors:**
```logql
{app="python-app", level="error"}
```

**Specific user:**
```logql
{app="python-app", user="alice"}
```

**Specific endpoint:**
```logql
{app="python-app", endpoint="/api/orders"}
```

**Search within logs:**
```logql
{app="python-app"} |= "timeout"
{app="python-app"} |= "Slow query"
{app="python-app"} |~ "alice|bob"  # regex
```

**Count logs:**
```logql
sum(count_over_time({app="python-app"}[5m]))
```

**Rate of logs by level:**
```logql
sum by (level) (rate({app="python-app"}[1m]))
```

## 📈 Testing Metrics (Prometheus/Mimir)

### Access Explore
1. Click **Explore** icon
2. Select **Prometheus** from dropdown

### Sample Queries

**Total logs generated:**
```promql
sum(generated_logs_total)
```

**Log rate by level:**
```promql
sum by (level) (rate(generated_logs_total[5m]))
```

**Error rate:**
```promql
rate(generated_logs_total{level="error"}[5m])
```

**Active connections:**
```promql
active_connections{environment="dev"}
```

**Request duration (95th percentile):**
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

**Request duration by endpoint:**
```promql
histogram_quantile(0.95, 
  sum by (endpoint, le) (
    rate(http_request_duration_seconds_bucket[5m])
  )
)
```

**Total requests per endpoint:**
```promql
sum by (endpoint) (http_request_duration_seconds_count)
```

## 🎨 Testing Dashboard

### Access Dashboard
1. Go to **Dashboards** → **Browse**
2. Click **LGTM Overview - DEV**

### Dashboard Panels

1. **Application Logs** (Top)
   - Live log stream from Python app
   - Auto-refreshes every 5 seconds
   - Shows timestamp, level, message

2. **Log Count by Level** (Bottom Left)
   - Timeseries graph
   - Shows rate of logs per second
   - Split by INFO/WARNING/ERROR

3. **Total Logs Generated** (Bottom Center)
   - Single stat
   - Cumulative count

4. **Active Connections** (Bottom Right)
   - Gauge visualization
   - Current simulated connections

### Dashboard Features
- **Auto-refresh**: Every 5 seconds
- **Time range**: Adjustable (top right)
- **Zoom**: Click and drag on graphs
- **Legend**: Click to filter

## 🧪 Advanced Testing

### Test Log Filtering

**Combine multiple labels:**
```logql
{app="python-app", level="error", endpoint="/api/orders"}
```

**Pattern matching:**
```logql
{app="python-app"} |~ "User '(alice|bob)'"
```

**JSON parsing (if logs were JSON):**
```logql
{app="python-app"} | json | duration > 1
```

### Test Metric Aggregation

**Average request duration:**
```promql
rate(http_request_duration_seconds_sum[5m]) / 
rate(http_request_duration_seconds_count[5m])
```

**Logs per minute:**
```promql
sum(increase(generated_logs_total[1m]))
```

**Error percentage:**
```promql
(
  rate(generated_logs_total{level="error"}[5m]) /
  rate(generated_logs_total[5m])
) * 100
```

### Test Alerting (Optional)

Create an alert rule:
1. Go to **Alerting** → **Alert rules**
2. Click **New alert rule**
3. Example: Alert if error rate > 10%

```promql
(
  rate(generated_logs_total{level="error"}[5m]) /
  rate(generated_logs_total[5m])
) * 100 > 10
```

## 🐛 Troubleshooting

### No Data in Dashboard

**Check datasources:**
```bash
# Test Loki
LOKI_POD=$(kubectl get pod -n monitoring -l app.kubernetes.io/name=loki -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n monitoring $LOKI_POD -- wget -q -O- 'http://localhost:3100/loki/api/v1/query?query={app="python-app"}'

# Test if Python app is running
kubectl logs -n development -l app=python-app --tail=20
```

**Restart Grafana:**
```bash
kubectl rollout restart deployment/grafana -n monitoring
```

### Query Not Working

1. Check time range (top right in Grafana)
2. Verify datasource is selected
3. Check label names are correct:
   ```bash
   # Query Loki labels
   LOKI_POD=$(kubectl get pod -n monitoring -l app.kubernetes.io/name=loki -o jsonpath='{.items[0].metadata.name}')
   kubectl exec -n monitoring $LOKI_POD -- wget -q -O- 'http://localhost:3100/loki/api/v1/labels'
   ```

### Python App Not Generating Logs

```bash
# Check pod status
kubectl get pods -n development

# Check logs for errors
kubectl logs -n development -l app=python-app --tail=50

# Restart pod
kubectl delete pod -n development -l app=python-app
```

## 📚 Sample Scenarios

### Scenario 1: Find All Errors in Last 5 Minutes
```logql
{app="python-app", level="error"} [5m]
```

### Scenario 2: Monitor Specific User Activity
```logql
{app="python-app", user="alice"}
```

### Scenario 3: Track Slow Queries
```logql
{app="python-app"} |= "Slow query"
```

### Scenario 4: Calculate Error Rate
```promql
sum(rate(generated_logs_total{level="error"}[5m])) / 
sum(rate(generated_logs_total[5m])) * 100
```

### Scenario 5: Compare Log Rates Over Time
```promql
sum by (level) (
  rate(generated_logs_total[5m] offset 1h)
) 
vs 
sum by (level) (
  rate(generated_logs_total[5m])
)
```

## 🎓 Learning Resources

- **LogQL**: https://grafana.com/docs/loki/latest/logql/
- **PromQL**: https://prometheus.io/docs/prometheus/latest/querying/basics/
- **Grafana Explore**: https://grafana.com/docs/grafana/latest/explore/
- **Dashboard Creation**: https://grafana.com/docs/grafana/latest/dashboards/

## ✅ Success Checklist

- [ ] Grafana accessible at localhost:3000
- [ ] Login successful
- [ ] Loki datasource configured and working
- [ ] Prometheus datasource configured and working
- [ ] Can see logs in Explore
- [ ] Can see metrics in Explore
- [ ] Dashboard loads and shows data
- [ ] Dashboard auto-refreshes
- [ ] Can filter logs by level, user, endpoint
- [ ] Can create custom queries
- [ ] Can visualize metrics

---

**Need Help?** Check `README.md` or run `kubectl logs -n development -l app=python-app` to see if logs are being generated.

