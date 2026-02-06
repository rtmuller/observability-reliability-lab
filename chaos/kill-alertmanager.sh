#!/usr/bin/env bash
# ---------------------------------------------------------------
# kill-alertmanager.sh
# Simulates an AlertManager failure to demonstrate silent alerts.
#
# What to observe:
#   1. Prometheus continues scraping and evaluating rules
#   2. Alerts fire in Prometheus (check /alerts endpoint)
#   3. BUT nobody gets notified — AlertManager is down
#   4. The Watchdog heartbeat stops reaching external services
#   5. Prometheus will show AlertManager as down (up{job="alertmanager"} == 0)
#
# Key insight:
#   Prometheus KNOWS AlertManager is down (check TargetDown alert).
#   But it can't TELL anyone — because the notification path is broken.
# ---------------------------------------------------------------

set -euo pipefail

echo "============================================"
echo "  CHAOS: Stopping AlertManager"
echo "============================================"
echo ""
echo "This simulates AlertManager crashing."
echo "Watch what happens:"
echo ""
echo "  → Prometheus: still scraping and evaluating"
echo "  → Alerts: fire in Prometheus but aren't delivered"
echo "  → Watchdog: heartbeat stops (no receiver)"
echo "  → Dashboards: still work (Grafana reads from Prometheus)"
echo ""
echo "Open these in your browser:"
echo "  Prometheus Alerts: http://localhost:9090/alerts"
echo "  AlertManager:      http://localhost:9093 (will fail)"
echo "  Grafana:           http://localhost:3000"
echo ""

docker stop alertmanager

echo ""
echo "============================================"
echo "  AlertManager is DOWN"
echo "============================================"
echo ""
echo "Check Prometheus alerts: http://localhost:9090/alerts"
echo "You'll see TargetDown firing for alertmanager."
echo ""
echo "But who gets notified? Nobody."
echo "That's the paradox."
echo ""
echo "Run ./restore-all.sh to bring everything back."
echo "============================================"
