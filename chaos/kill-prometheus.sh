#!/usr/bin/env bash
# ---------------------------------------------------------------
# kill-prometheus.sh
# Simulates a Prometheus failure to demonstrate blind spots.
#
# What to observe:
#   1. Grafana dashboards will stop updating (no new data points)
#   2. AlertManager will stop receiving alerts
#   3. The Watchdog (DeadMansSwitch) heartbeat will stop
#   4. absent() rules can no longer evaluate
#   5. Yet no alert fires — because the alerting engine IS the failure
#
# This is the core scenario from the article:
#   "What happens when the system responsible for detecting
#    failures is itself the thing that fails?"
# ---------------------------------------------------------------

set -euo pipefail

echo "============================================"
echo "  CHAOS: Stopping Prometheus"
echo "============================================"
echo ""
echo "This simulates Prometheus being OOMKilled or"
echo "losing its node. Watch what happens:"
echo ""
echo "  → Grafana: dashboards freeze (no new data)"
echo "  → AlertManager: no new alerts arrive"
echo "  → Watchdog: heartbeat stops (DeadMansSwitch)"
echo "  → absent(): can't evaluate (Prometheus is gone)"
echo ""
echo "Open these in your browser:"
echo "  Grafana:      http://localhost:3000"
echo "  AlertManager: http://localhost:9093"
echo "  Prometheus:   http://localhost:9090 (will fail)"
echo ""

docker stop prometheus

echo ""
echo "============================================"
echo "  Prometheus is DOWN"
echo "============================================"
echo ""
echo "Check AlertManager at http://localhost:9093"
echo "Notice: the Watchdog alert will become stale"
echo "and eventually disappear."
echo ""
echo "In a real system without meta-monitoring,"
echo "nobody would know."
echo ""
echo "Run ./restore-all.sh to bring everything back."
echo "============================================"
