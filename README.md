# Observability Reliability Lab

A hands-on lab that demonstrates why your monitoring pipeline is a single point of failure — and how meta-monitoring fixes it.

---

## The Observability Trilogy

This lab is the companion to a three-part article series on building intentional, reliable, and cost-effective observability for cloud-native systems at scale.

Each article tackles a different dimension of observability maturity — and each one builds on the lessons of the previous.

### Article 1 — [Beyond Monitoring: The Hidden Cost of Observability at Scale](https://medium.com/@rafael_muller/beyond-monitoring-the-hidden-cost-of-observability-at-scale-adbee5ae5f8a)

Observability costs don't explode because of traffic — they explode because of unchecked **cardinality**. A single unbounded label like `request_id` or `collection_id` can silently generate hundreds of thousands of active time series. This article covers how a single high-cardinality label caused an 81% cost increase in Grafana Cloud, and how relabeling rules and metric auditing bring costs back under control.

### Article 2 — [The Silent Killer: Why "No Data" Is Often Worse Than Bad Data](https://medium.com/@rafael_muller/the-silent-killer-why-no-data-is-often-worse-than-bad-data-c811fa664371)

Most alerts assume data exists — they trigger when a metric crosses a threshold. But when a metric **disappears entirely**, the alert never fires. There's no alarm, no page, just silence. This article introduces Prometheus's `absent()` function as a way to detect when critical metrics stop reporting — turning silence into an actionable signal.

### Article 3 — The Observability Reliability Paradox *(this lab)*

You've got cardinality under control. You're alerting on missing data. But what happens when **Prometheus itself goes down**? Your `absent()` rules can't evaluate. Your Watchdog heartbeat stops. Your dashboards freeze. And nobody gets notified — because the notification path runs through the very system that failed. This lab lets you experience that blind spot firsthand and demonstrates the meta-monitoring patterns that solve it.

---

## What This Lab Demonstrates

Most teams build alerting around thresholds and missing data — but never test what happens when the **monitoring stack itself fails**.

This lab lets you:

- Run a full Prometheus + AlertManager + Grafana stack locally
- **Kill Prometheus** and watch dashboards freeze, alerts go silent, and `absent()` rules become useless
- **Kill AlertManager** and see Prometheus detect the failure but fail to notify anyone
- Understand why **meta-monitoring** (Watchdog alerts, external heartbeats, blackbox probes) is the missing layer

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                     Docker Network                        │
│                                                           │
│  ┌──────────────┐     scrapes      ┌───────────────────┐ │
│  │  Prometheus   │◄────────────────│  Payment Service   │ │
│  │  :9090        │                 │  :8000             │ │
│  └──────┬───────┘                 └───────────────────┘ │
│         │                                                 │
│    alerts│         ┌───────────────────┐                  │
│         ▼         │ Blackbox Exporter  │                  │
│  ┌──────────────┐ │  :9115            │                  │
│  │ AlertManager  │ │  (probes health   │                  │
│  │  :9093        │ │   endpoints)      │                  │
│  └──────────────┘ └───────────────────┘                  │
│                                                           │
│  ┌──────────────┐                                         │
│  │   Grafana     │  ← Meta-Monitoring Dashboard           │
│  │  :3000        │                                        │
│  └──────────────┘                                         │
└──────────────────────────────────────────────────────────┘
```

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and Docker Compose
- Ports `3000`, `8000`, `9090`, `9093`, `9115` available

## Quick Start

```bash
# Clone the repo
git clone https://github.com/rtmuller/observability-reliability-lab.git
cd observability-reliability-lab

# Start everything
docker compose up -d --build

# Verify all services are running
docker compose ps
```

### Access the UIs

| Service          | URL                            | Credentials   |
|------------------|--------------------------------|---------------|
| **Grafana**      | http://localhost:3000           | admin / admin |
| **Prometheus**   | http://localhost:9090           | —             |
| **AlertManager** | http://localhost:9093           | —             |
| **Blackbox**     | http://localhost:9115           | —             |
| **Payment App**  | http://localhost:8000/metrics   | —             |

Open Grafana and navigate to **Dashboards → Meta-Monitoring — Observability Reliability** to see the pre-built dashboard.

---

## Chaos Scenarios

### Scenario 1: Kill Prometheus

Simulates Prometheus being OOMKilled or evicted from a node.

```bash
./chaos/kill-prometheus.sh
```

**What happens:**

```
Prometheus Health Endpoint:
  CONNECTION REFUSED (Prometheus is down)

Payment Service:
  OK (app is fine, but nobody is watching it)

Grafana:
  Cannot reach Prometheus — dashboards are frozen

AlertManager Active Alerts:
  Watchdog       status=active (stale — will expire)

Blackbox probe for Prometheus:
  probe_success = 0 (FAIL — Prometheus unreachable)
```

Blackbox Exporter **detects** Prometheus is down. But Prometheus is the one that reads blackbox results. Nobody is consuming the data. The detection is useless.

### Scenario 2: Kill AlertManager

Simulates AlertManager crashing or becoming unreachable.

```bash
./chaos/kill-alertmanager.sh
```

**What happens:**

```
Prometheus Firing Alerts:
  [critical] TargetDown              target=alertmanager:9093
  [critical] MonitoringComponentDown target=http://alertmanager:9093/-/healthy

Prometheus Notification Delivery:
  notifications_dropped_total = 10
  notifications_errors_total  = 9

Blackbox probe for AlertManager:
  probe_success = 0 (FAIL — AlertManager unreachable)
```

Prometheus **knows** AlertManager is down. It fires critical alerts. But it delivers alerts through AlertManager — the very thing that's broken. 10 dropped notifications. Nobody gets paged.

### Restore Everything

```bash
./chaos/restore-all.sh
```

---

## Key Concepts

### Watchdog Alert (DeadMansSwitch)

An alert that **always fires**. If it stops, your pipeline is broken.

```yaml
- alert: Watchdog
  expr: vector(1)
  labels:
    severity: none
```

Route it to an external heartbeat service (Healthchecks.io, PagerDuty, Deadman's Snitch). If the heartbeat stops arriving, the external service alerts you through an independent path.

### Blackbox Health Probes

Probes the health endpoints of monitoring components themselves:

- `http://prometheus:9090/-/healthy`
- `http://alertmanager:9093/-/healthy`
- `http://grafana:3000/api/health`

### absent() Rules

From [Article 2](https://medium.com/@rafael_muller/the-silent-killer-why-no-data-is-often-worse-than-bad-data-c811fa664371) — detects when metrics disappear. But as this lab demonstrates, `absent()` only works if Prometheus is alive to evaluate it.

---

## File Structure

```
.
├── docker-compose.yml              # Full stack definition
├── app/
│   ├── Dockerfile                  # Sample payment service
│   ├── main.py                     # Python app with Prometheus metrics
│   └── requirements.txt
├── prometheus/
│   ├── prometheus.yml              # Scrape config + meta-monitoring
│   └── alerts/
│       ├── watchdog.yml            # Watchdog, TargetDown, meta-alerts
│       └── absent.yml              # absent() rules
├── alertmanager/
│   └── alertmanager.yml            # Routing with DeadMansSwitch receiver
├── blackbox/
│   └── blackbox.yml                # HTTP health probe config
├── grafana/
│   ├── datasources.yml             # Auto-provisioned Prometheus source
│   └── dashboards/
│       ├── dashboard.yml           # Provisioning config
│       └── meta-monitoring.json    # Pre-built dashboard
└── chaos/
    ├── kill-prometheus.sh          # Stop Prometheus
    ├── kill-alertmanager.sh        # Stop AlertManager
    └── restore-all.sh             # Restore all services
```

## Cleanup

```bash
docker compose down -v
```

## License

MIT

---

**Author:** [Rafael Muller](https://github.com/rtmuller) — Senior Cloud Engineer at Airbnb, working on platform infrastructure at 8M+ listings scale. Writing at [Medium](https://medium.com/@rafael_muller).
