# Homelab Assistant Rules & Connection Memory

This repository (`~/home-lab-assistant`) is the central workspace for managing the user's homelab infrastructure, nodes, services, and runbooks.

## 1. How to Remember & Update Nodes and Services

Whenever the user shares or deploys a new host, IP address, SSH alias, or service:
1. **Register or update nodes immediately**:
   ```bash
   ./scripts/hl-inventory.sh add-node "<name>" "<ssh_alias>" "<ip>" "<role>" "<key_paths_and_notes>"
   ```
2. **Register or update services immediately**:
   ```bash
   ./scripts/hl-inventory.sh add-service "<id>" "<node>" "<type>" "<path_or_unit>" "<url_or_port>" "<notes>"
   ```
   - Supported `<type>` values: `compose`, `docker`, `systemd`, `k8s`, `proxmox`, `baremetal`, `external`.
   - Both commands update `inventory/*.tsv` and auto-sync the **Quick Node Registry** and **Quick Service Registry** tables below in `AGENTS.md` so they are always in context.
   - To bulk-discover existing services on a node, run `./scripts/hl-service.sh discover <node> [--apply]`.
3. **Never store raw passwords, private keys, or API tokens in `AGENTS.md` or `inventory/`.**
   - SSH authentication must use `~/.ssh/config` host aliases and key-based auth (set up via `.agents/skills/homelab-connection/scripts/setup-ssh-host.sh`).
   - Service secrets follow a strict naming convention in `.env` (`<SERVICE_ID>_URL`, `<SERVICE_ID>_TOKEN`, `<SERVICE_ID>_API_KEY`, `<SERVICE_ID>_USER`, `<SERVICE_ID>_PASSWORD`) or live in per-service `secrets/<service_id>.env` files (both gitignored).
4. **Remote execution & service management**:
   - Use `./scripts/hl-ssh.sh <host> "<command>"` for non-interactive remote commands with SSH multiplexing.
   - Use `./scripts/hl-service.sh <status|logs|restart|update|env> <service_id>` to operate any registered service regardless of whether it runs via Docker Compose, systemd, or Kubernetes.

## 2. Quick Node Registry (Always-On Memory)

<!-- NODE_REGISTRY_START -->
| Node Name | SSH Alias / Host | LAN / VPN IP | Role / OS | Key Paths & Notes |
| :--- | :--- | :--- | :--- | :--- |
| *No nodes registered yet* | `-` | `-` | Run `./scripts/hl-inventory.sh add-node ...` | `-` |
<!-- NODE_REGISTRY_END -->

## 3. Quick Service Registry (Always-On Memory)

<!-- SERVICE_REGISTRY_START -->
| Service ID | Node | Type | Path / Unit / Namespace | URL / Port | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| *No services registered yet* | `-` | `-` | Run `./scripts/hl-inventory.sh add-service ...` | `-` | `-` |
<!-- SERVICE_REGISTRY_END -->

## 4. Operational Safety Guardrails

- **Read-only first**: Inspect status, logs, and configuration (`./scripts/hl-service.sh status`, `docker compose ps`, `kubectl get`, `zfs list`, `systemctl status`) before making state changes.
- **Destructive actions require confirmation**: Always ask the user before:
  - Rebooting or shutting down physical nodes or hypervisors
  - Deleting ZFS datasets/snapshots, persistent volumes, or backup repositories
  - Flushing firewall rules or modifying primary network/SSH interfaces (risk of lockout)
  - Running `docker system prune -a --volumes` or deleting database/application data directories
- **Config backups**: Before editing critical remote configs (reverse proxies, `/etc/fstab`, `/etc/ssh/sshd_config`, Docker Compose files), verify a backup or snapshot exists and validate syntax (`nginx -t`, `caddy validate`, `docker compose config`) before reloading.
