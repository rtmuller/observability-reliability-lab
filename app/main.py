"""
Sample payment service that exposes Prometheus metrics.
Used to demonstrate meta-monitoring and failure detection patterns.
"""

import time
import random
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
from prometheus_client import (
    Counter,
    Histogram,
    Gauge,
    generate_latest,
    CONTENT_TYPE_LATEST,
)

# --- Metrics ---

TRANSACTIONS_TOTAL = Counter(
    "transactions_total",
    "Total number of transactions processed",
    ["service", "status"],
)

TRANSACTION_DURATION = Histogram(
    "transaction_duration_seconds",
    "Transaction processing duration in seconds",
    ["service"],
    buckets=[0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5],
)

SERVICE_UP = Gauge(
    "service_up",
    "Whether the service is healthy",
    ["service"],
)

# --- Simulated workload ---

def simulate_transactions():
    """Continuously simulate transaction processing."""
    SERVICE_UP.labels(service="checkout").set(1)

    while True:
        # Simulate normal transactions
        status = random.choices(
            ["success", "error"],
            weights=[95, 5],
            k=1,
        )[0]

        duration = random.uniform(0.01, 0.3)
        if status == "error":
            duration = random.uniform(0.5, 2.0)

        TRANSACTIONS_TOTAL.labels(service="checkout", status=status).inc()
        TRANSACTION_DURATION.labels(service="checkout").observe(duration)

        time.sleep(random.uniform(0.1, 0.5))


# --- HTTP Server ---

class MetricsHandler(BaseHTTPRequestHandler):
    """HTTP handler that serves metrics and health endpoints."""

    # HTTP/1.1 for blackbox-exporter compatibility
    protocol_version = "HTTP/1.1"

    def _send(self, code, content_type, body):
        """Send a complete response with proper headers."""
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/metrics":
            self._send(200, CONTENT_TYPE_LATEST, generate_latest())
        elif self.path == "/health":
            self._send(200, "text/plain", b"OK")
        else:
            self._send(404, "text/plain", b"Not Found")

    def log_message(self, format, *args):
        """Suppress default logging to keep output clean."""
        pass


if __name__ == "__main__":
    # Start background transaction simulator
    worker = threading.Thread(target=simulate_transactions, daemon=True)
    worker.start()

    # Start HTTP server
    server = HTTPServer(("0.0.0.0", 8000), MetricsHandler)
    print("Sample payment service running on :8000")
    print("  /metrics  - Prometheus metrics")
    print("  /health   - Health check endpoint")
    server.serve_forever()
