---
name: service-lifecycle
description: >-
  Use this skill when onboarding, deploying, registering, inspecting, updating, or
  removing ANY service or application in the homelab (Docker Compose, standalone container,
  systemd unit, Kubernetes workload, VM/LXC, or external appliance).
---

# Universal Service Lifecycle & Onboarding Skill

Use this skill whenever the user introduces an existing service, wants to deploy a new service, or asks to check/update/manage any application in the homelab.

## Helpers & References

- [`hl-inventory.sh`](../../../../scripts/hl-inventory.sh): Registers services in `inventory/services.tsv`, auto-syncs `AGENTS.md`, and optionally generates `<SERVICE_ID>_*` placeholders in `.env.example`.
- [`hl-service.sh`](../../../../scripts/hl-service.sh): Runtime-agnostic controller (`status`, `logs`, `restart`, `update`, `env`, `discover`) for any registered service.
- [`workload-archetypes.md`](./references/workload-archetypes.md): Reusable patterns for common service types (Web/API + Database stacks, GPU/hardware-accelerated containers, shared-volume/hardlink pipelines, and host-network daemons).

## Standard Service Onboarding Workflow

### 1. Discover or Deploy the Service
- **Existing services on a node**: Auto-discover running Compose stacks:
  ```bash
  ./scripts/hl-service.sh discover <node>
  # Or import them directly into the registry:
  ./scripts/hl-service.sh discover <node> --apply
  ```
- **Deploying a new service**:
  1. Check target node resources and free ports (`./scripts/hl-ssh.sh <host> "ss -tulpn"`).
  2. Pick the appropriate pattern from [`workload-archetypes.md`](./references/workload-archetypes.md) and [`compose-hardened-template.yml`](../docker-stacks/examples/compose-hardened-template.yml).
  3. Create the remote stack directory (e.g., `/opt/stacks/<service-id>/compose.yaml`) and validate syntax with `docker compose config -q`.

### 2. Register the Service in Always-On Memory
Always register the service so every future session knows where it lives and how to reach it:
```bash
./scripts/hl-inventory.sh add-service \
  "<service-id>" \
  "<node>" \
  "<type: compose|docker|systemd|k8s|proxmox|external>" \
  "<path_or_unit_or_namespace>" \
  "<url_or_port>" \
  "<notes>" \
  --with-env
```

### 3. Configure Secrets via Naming Convention
Never hardcode service secrets into scripts or git-tracked files:
- Global `.env` uses uppercase `<SERVICE_ID>_*` (hyphens converted to underscores):
  - `<SERVICE_ID>_URL`
  - `<SERVICE_ID>_API_KEY` or `<SERVICE_ID>_TOKEN`
  - `<SERVICE_ID>_USER` / `<SERVICE_ID>_PASSWORD`
- Stack-specific environment files can be stored locally in `secrets/<service-id>.env` (gitignored) and copied to the remote stack directory when needed.
- Verify resolved environment variables with:
  ```bash
  ./scripts/hl-service.sh env <service-id>
  ```

### 4. Operate & Verify Health
Use `hl-service.sh` to manage any registered service uniformly:
```bash
./scripts/hl-service.sh status <service-id>
./scripts/hl-service.sh logs <service-id> 100
./scripts/hl-service.sh restart <service-id>
./scripts/hl-service.sh update <service-id>
```

### 5. Optional Per-Service Runbooks
If a service has custom operational procedures, API queries, or backup hooks, document them in `docs/services/<service-id>.md` rather than hardcoding them into global rules.
