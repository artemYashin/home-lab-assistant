---
name: monitoring-logs
description: >-
  Use this skill when diagnosing homelab alerts, high CPU/RAM/IO usage, systemd service
  failures, journalctl logs, or managing Prometheus, Grafana, and Uptime Kuma.
---

# Monitoring, Systemd & Log Triage Skill

Use this skill to investigate incidents, resource bottlenecks, and monitoring stacks (Prometheus, Grafana, Uptime Kuma).

## Helper Scripts

- [`host-triage.sh`](./scripts/host-triage.sh): All-in-one diagnostic sweep (load average, Linux PSI pressure stalls for CPU/Memory/IO, RAM/Swap, top CPU & RAM processes, failed systemd units, kernel/OOM errors, and unhealthy Docker containers).

## Workflows

### 1. Run Host Triage Sweep
```bash
./.agents/skills/monitoring-logs/scripts/host-triage.sh <host>
```

### 2. Inspect a Systemd Service & Logs
```bash
./scripts/hl-ssh.sh <host> "systemctl status <unit> --no-pager && journalctl -u <unit> -n 100 --no-pager"
```

### 3. Reclaim Systemd Journal Space Safely
```bash
./scripts/hl-ssh.sh <host> "journalctl --disk-usage && sudo journalctl --vacuum-size=500M"
```

### 4. Query Prometheus Alerts & Down Targets
```bash
# Unhealthy scrape targets:
curl -s "${PROMETHEUS_URL}/api/v1/targets" | jq '.data.activeTargets[] | select(.health != "up") | {job: .labels.job, instance: .labels.instance, lastError: .lastError}'

# Active firing alerts:
curl -s "${PROMETHEUS_URL}/api/v1/alerts" | jq '.data.alerts[] | select(.state == "firing")'
```
