---
name: homelab-runbooks
description: >-
  Use this skill for multi-step homelab maintenance runbooks: safe OS upgrades and node
  reboots, power-outage / UPS shutdown and boot order, or migrating a service between nodes.
---

# Homelab Maintenance & Migration Runbooks

## 1. Safe Host OS Upgrade & Reboot Runbook

1. **Pre-flight Check**:
   - Check running workloads (`docker ps`, `kubectl get nodes`, active Jellyfin streams).
   - Take a ZFS snapshot of critical appdata if applicable.
2. **Apply Packages**:
   - Debian/Ubuntu: `sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y`
   - Check if reboot is required: `test -f /var/run/reboot-required && cat /var/run/reboot-required.pkgs`
3. **Drain / Quiesce (Before Reboot — Always Confirm with User First)**:
   - If Kubernetes node: `kubectl cordon <node> && kubectl drain <node> --ignore-daemonsets --delete-emptydir-data`
   - Verify `/etc/fstab` syntax (`sudo findmnt --verify`) so the host will not drop into emergency mode on boot!
4. **Post-Reboot Verification**:
   - Wait for SSH (`./scripts/hl-ssh.sh --check <host>`).
   - Run `./.agents/skills/monitoring-logs/scripts/host-triage.sh <host>`.
   - If Kubernetes node: `kubectl uncordon <node>`.

## 2. Service Migration Between Homelab Nodes

1. **Lower DNS TTL** (or prepare AdGuard/Pi-hole rewrite update).
2. **Sync Data First (While Service is Still Running)**:
   `rsync -avHAX --numeric-ids --info=progress2 <src_dir>/ <dest_host>:<dest_dir>/`
3. **Stop Source Stack & Final Delta Sync**:
   - Stop source: `docker compose down`
   - Final fast `rsync --delete` so SQLite/database files are copied in a clean stopped state.
4. **Start Target Stack & Update Reverse Proxy / DNS**:
   - Bring up target stack (`docker compose up -d`), verify logs, and switch reverse proxy upstream IP.
