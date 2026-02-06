#!/usr/bin/env bash
# ---------------------------------------------------------------
# restore-all.sh
# Restores all monitoring components to healthy state.
# ---------------------------------------------------------------

set -euo pipefail

echo "============================================"
echo "  RESTORE: Bringing all services back up"
echo "============================================"
echo ""

docker start prometheus 2>/dev/null && echo "  ✓ Prometheus started" || echo "  - Prometheus was already running"
docker start alertmanager 2>/dev/null && echo "  ✓ AlertManager started" || echo "  - AlertManager was already running"

echo ""
echo "Waiting 15 seconds for services to stabilize..."
sleep 15

echo ""
echo "============================================"
echo "  All services restored"
echo "============================================"
echo ""
echo "What to verify:"
echo "  → Prometheus:   http://localhost:9090/targets (all targets UP)"
echo "  → AlertManager: http://localhost:9093 (Watchdog alert present)"
echo "  → Grafana:      http://localhost:3000 (dashboards updating)"
echo ""
echo "Notice the gap in time series data on Grafana."
echo "That gap represents the blind spot — the period"
echo "where your monitoring wasn't monitoring."
echo "============================================"
