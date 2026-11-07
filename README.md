# Homelab Assistant (`~/home-lab-assistant`)

A universal, agent-agnostic homelab workspace with **always-on node & service memory**, **progressive-disclosure skills**, and **runtime-agnostic control scripts**. Compatible out-of-the-box with Antigravity, Claude Code, Cursor, Codex, Gemini CLI, Windsurf, Copilot, Cline, Roo, OpenCode, and Goose via symlinks to `.agents/` and `AGENTS.md`.

## Repository Layout

```text
~/home-lab-assistant/
├── AGENTS.md                          # Always-on rules + Node & Service Registries (auto-synced)
├── .env.example                       # Convention-based secret template (.env is gitignored)
├── secrets/                           # Optional per-service env files: secrets/<service-id>.env
├── inventory/
│   ├── nodes.tsv                      # Node registry synced into AGENTS.md
│   ├── services.tsv                   # Service registry synced into AGENTS.md
│   └── hosts.yaml                     # Freeform hardware, VLAN, storage, and cluster topology
├── scripts/
│   ├── hl-ssh.sh                      # Fast multiplexed non-interactive SSH wrapper
│   ├── hl-inventory.sh                # CLI to add/remove/query nodes & services and sync AGENTS.md
│   └── hl-service.sh                  # Universal controller (status/logs/restart/update/discover/env)
├── docs/
│   └── services/                      # Optional per-service notes/runbooks: docs/services/<id>.md
├── stacks/
│   └── snapshots/                     # Automatic pre-update Docker image digest snapshots
└── .agents/
    └── skills/                        # 10 Generic On-Demand Skills (progressive disclosure)
        ├── homelab-connection/        # SSH setup, host discovery, and inventory registration
        ├── service-lifecycle/         # Onboarding, deploying, and operating ANY homelab service
        ├── docker-stacks/             # Remote Docker Compose deployment, updates, and rollbacks
        ├── kubernetes-ops/            # k3s / k8s / Talos cluster & workload management
        ├── networking-proxy/          # Reverse proxies, local DNS, TLS, and firewall routing
        ├── storage-backups/           # ZFS, NAS mounts, SMART health, and Restic/Borg backups
        ├── monitoring-logs/           # Host CPU/RAM/PSI triage, systemd logs, and alerts
        ├── security-hardening/        # SSH/UFW/Docker port auditing and hardening
        ├── systemd-timers-cron/       # Systemd service, timer, and mount unit management
        └── homelab-runbooks/          # Safe OS upgrades, UPS shutdown order, and service migration
```

## Quick Start: Adding Nodes & Services

1. **Add a Node**:
   ```bash
   ./.agents/skills/homelab-connection/scripts/setup-ssh-host.sh hl-main 192.168.1.10 artem
   ./scripts/hl-inventory.sh add-node "hl-main" "hl-main" "192.168.1.10" "Docker / ZFS" "Stacks: /opt/stacks"
   ```
2. **Add Any Service (or Auto-Discover Existing Ones)**:
   ```bash
   # Auto-discover all running Docker Compose stacks on a node:
   ./scripts/hl-service.sh discover hl-main --apply

   # Or register any service (compose, docker, systemd, k8s, proxmox, external):
   ./scripts/hl-inventory.sh add-service "immich" "hl-main" "compose" "/opt/stacks/immich" "https://photos.lab.local" "Photo backup" --with-env
   ```
3. **Operate Any Registered Service**:
   ```bash
   ./scripts/hl-service.sh status --all
   ./scripts/hl-service.sh logs <service-id> 100
   ./scripts/hl-service.sh restart <service-id>
   ./scripts/hl-service.sh update <service-id>
   ```
4. **Secrets Convention**:
   - Global `.env` uses `<SERVICE_ID>_URL`, `<SERVICE_ID>_API_KEY`, `<SERVICE_ID>_TOKEN`, `<SERVICE_ID>_USER`, `<SERVICE_ID>_PASSWORD`.
   - Or place service-specific env files in `secrets/<service-id>.env` (gitignored).
