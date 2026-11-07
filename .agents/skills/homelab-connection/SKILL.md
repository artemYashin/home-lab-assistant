---
name: homelab-connection
description: >-
  Use this skill when adding, updating, testing, or troubleshooting SSH connections
  to homelab nodes, discovering services on a new host, or updating the remembered
  homelab inventory in AGENTS.md, inventory/nodes.tsv, and inventory/services.tsv.
---

# Homelab Connection & Discovery Skill

This skill governs how homelab connections are established, verified, auto-discovered, and permanently remembered in `~/home-lab-assistant`.

## Helper Scripts

- [`setup-ssh-host.sh`](./scripts/setup-ssh-host.sh): Appends a standardized `Host` block to `~/.ssh/config`.
- [`discover-node.sh`](./scripts/discover-node.sh): Runs a single read-only discovery sweep over SSH (OS, CPU/RAM, IPs, filesystems, ZFS pools, Docker stacks, K8s nodes, listening ports).
- [`hl-inventory.sh`](../../../../scripts/hl-inventory.sh): Updates `inventory/nodes.tsv` and `inventory/services.tsv`, and auto-syncs the **Quick Node Registry** and **Quick Service Registry** tables in `AGENTS.md`.
- [`hl-service.sh`](../../../../scripts/hl-service.sh): Discovers and operates services across any node.

## Workflow

1. **Configure SSH Alias**:
   ```bash
   ./.agents/skills/homelab-connection/scripts/setup-ssh-host.sh <alias> <ip> <user> [port]
   ```
2. **Verify Non-Interactive SSH Connectivity**:
   ```bash
   ./scripts/hl-ssh.sh --check <alias>
   ```
   *(If SSH key auth is not yet copied to the host, ask the user to run `ssh-copy-id <alias>` once in their terminal.)*
3. **Run Node Discovery Sweep**:
   ```bash
   ./.agents/skills/homelab-connection/scripts/discover-node.sh <alias>
   ```
4. **Persist Node & Discovered Services to Always-On Memory**:
   - Register the node:
     ```bash
     ./scripts/hl-inventory.sh add-node "<name>" "<alias>" "<ip>" "<roles>" "<key_paths_and_notes>"
     ```
   - Auto-discover and register running services on that node:
     ```bash
     ./scripts/hl-service.sh discover "<name>" --apply
     ```
   - Or register individual services explicitly:
     ```bash
     ./scripts/hl-inventory.sh add-service "<id>" "<name>" "<type>" "<path_or_unit>" "<url_or_port>" "<notes>" --with-env
     ```
   - Record any additional hardware/storage topology details in `inventory/hosts.yaml`.
