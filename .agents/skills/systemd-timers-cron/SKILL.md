---
name: systemd-timers-cron
description: >-
  Use this skill when creating, inspecting, or debugging systemd services, systemd timers,
  mount/automount units, and scheduled maintenance jobs on homelab nodes.
---

# Systemd Services, Timers & Mounts Skill

Prefer `systemd` `.service` + `.timer` units over legacy `crontab` entries on homelab nodes so every scheduled job gets structured `journalctl` logging, exit code tracking, `RandomizedDelaySec`, and `systemctl --failed` alerting.

## 1. Inspecting Active Timers

```bash
./scripts/hl-ssh.sh <host> "systemctl list-timers --all --no-pager"
```

## 2. Template: Hardened Systemd Service + Timer

### `/etc/systemd/system/homelab-task.service`
```ini
[Unit]
Description=Homelab Scheduled Task
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=root
ExecStart=/usr/local/bin/homelab-task.sh
StandardOutput=journal
StandardError=journal
```

### `/etc/systemd/system/homelab-task.timer`
```ini
[Unit]
Description=Run Homelab Scheduled Task Daily

[Timer]
OnCalendar=*-*-* 03:15:00
RandomizedDelaySec=15m
Persistent=true

[Install]
WantedBy=timers.target
```

Enable and test:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now homelab-task.timer
sudo systemctl start homelab-task.service
journalctl -u homelab-task.service -n 50 --no-pager
```
