import os
import json
import logging
import random
import threading
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

from prometheus_client import start_http_server, Counter, Histogram, Gauge
import requests


LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
ENVIRONMENT = os.getenv("ENVIRONMENT", "dev")
LOKI_URL = os.getenv("LOKI_URL", "http://loki.monitoring.svc.cluster.local:3100")
METRICS_PORT = int(os.getenv("METRICS_PORT", "8000"))

logging.basicConfig(
    level=getattr(logging, LOG_LEVEL, logging.INFO),
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s"
)
logger = logging.getLogger("python-app")

# Prometheus metrics
log_counter = Counter(
    "generated_logs_total",
    "Total generated log lines",
    ["level", "environment"]
)

request_duration = Histogram(
    "http_request_duration_seconds",
    "HTTP request duration in seconds",
    ["method", "endpoint"]
)

active_connections = Gauge(
    "active_connections",
    "Number of active connections",
    ["environment"]
)

# Sample data generators
USERS = ["alice", "bob", "charlie", "diana", "eve"]
ENDPOINTS = ["/api/users", "/api/orders", "/api/products", "/api/health", "/api/login"]
ACTIONS = ["created", "updated", "deleted", "fetched", "validated"]
ERRORS = [
    "Connection timeout to database",
    "Invalid authentication token",
    "Rate limit exceeded",
    "Service unavailable",
    "NULL pointer exception",
]


def push_to_loki(level: str, message: str, extra_labels: dict = None) -> None:
    """Push logs to Loki"""
    ts_ns = int(time.time() * 1e9)
    labels = {
        "app": "python-app",
        "namespace": "development",
        "environment": ENVIRONMENT,
        "level": level.lower(),
    }
    if extra_labels:
        labels.update(extra_labels)
    
    streams = [{
        "stream": labels,
        "values": [[str(ts_ns), message]],
    }]
    
    try:
        resp = requests.post(
            f"{LOKI_URL}/loki/api/v1/push",
            data=json.dumps({"streams": streams}),
            headers={"Content-Type": "application/json"},
            timeout=3
        )
        resp.raise_for_status()
    except Exception as e:
        logger.error(f"Failed to push to Loki: {e}")


def generate_realistic_logs():
    """Generate realistic application logs"""
    while True:
        log_type = random.choices(
            ["info", "warning", "error"],
            weights=[70, 20, 10]  # 70% info, 20% warning, 10% error
        )[0]
        
        if log_type == "info":
            user = random.choice(USERS)
            endpoint = random.choice(ENDPOINTS)
            action = random.choice(ACTIONS)
            duration = random.uniform(0.01, 2.0)
            
            msg = f"User '{user}' {action} resource at {endpoint} (duration: {duration:.3f}s)"
            logger.info(msg)
            push_to_loki("INFO", msg, {"user": user, "endpoint": endpoint})
            
            # Update metrics
            request_duration.labels(method="GET", endpoint=endpoint).observe(duration)
            
        elif log_type == "warning":
            user = random.choice(USERS)
            msg = f"Slow query detected for user '{user}' - took {random.uniform(2, 5):.2f}s"
            logger.warning(msg)
            push_to_loki("WARNING", msg, {"user": user})
            
        else:  # error
            error_msg = random.choice(ERRORS)
            endpoint = random.choice(ENDPOINTS)
            msg = f"Error at {endpoint}: {error_msg}"
            logger.error(msg)
            push_to_loki("ERROR", msg, {"endpoint": endpoint})
        
        # Update counter
        log_counter.labels(level=log_type, environment=ENVIRONMENT).inc()
        
        # Simulate varying active connections
        active_connections.labels(environment=ENVIRONMENT).set(random.randint(5, 50))
        
        # Random delay between logs (reduced frequency for testing)
        time.sleep(random.uniform(5.0, 10.0))  # One log every 5-10 seconds


class MetricsHandler(BaseHTTPRequestHandler):
    """HTTP handler for health checks"""
    
    def log_message(self, format, *args):
        """Suppress default logging"""
        pass
    
    def do_GET(self):
        if self.path == "/healthz":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"OK")
        else:
            self.send_response(404)
            self.end_headers()


def run_health_server():
    """Run health check server"""
    server = HTTPServer(("0.0.0.0", 8080), MetricsHandler)
    logger.info(f"Health check server started on port 8080")
    server.serve_forever()


if __name__ == "__main__":
    logger.info(f"Starting Python App - Environment: {ENVIRONMENT}")
    logger.info(f"Metrics exposed on port {METRICS_PORT}")
    logger.info(f"Pushing logs to Loki at {LOKI_URL}")
    
    # Start Prometheus metrics server
    start_http_server(METRICS_PORT)
    logger.info(f"Prometheus metrics server started on :{METRICS_PORT}/metrics")
    
    # Start health check server
    threading.Thread(target=run_health_server, daemon=True).start()
    
    # Generate logs
    generate_realistic_logs()
