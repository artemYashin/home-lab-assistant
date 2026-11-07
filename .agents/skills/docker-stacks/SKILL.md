---
name: docker-stacks
description: >-
  Use this skill when deploying, updating, inspecting, or troubleshooting Docker
  containers and Docker Compose stacks on homelab nodes over SSH.
---

# Docker & Docker Compose Stack Management

Use this skill for all container lifecycle tasks across homelab Docker hosts.

## Resources & Helpers

- [`remote-compose.sh`](./scripts/remote-compose.sh): Remote Compose wrapper that supports `list`, `status`, `logs`, `validate`, and `update` (automatically saving pre-update image digests to `stacks/snapshots/` before pulling).
- [`compose-hardened-template.yml`](./examples/compose-hardened-template.yml): Reference Compose template with log rotation, `no-new-privileges:true`, healthchecks, and Traefik labels.

## Workflows

### 1. Inspect Stacks & Containers
```bash
./.agents/skills/docker-stacks/scripts/remote-compose.sh <host> list
./.agents/skills/docker-stacks/scripts/remote-compose.sh <host> status <stack_dir>
```

### 2. Safe Stack Update (with Pre-Update Digest Snapshot)
```bash
./.agents/skills/docker-stacks/scripts/remote-compose.sh <host> update <stack_dir>
```
This automatically records current image tags and SHA256 digests in `stacks/snapshots/<host>_<stack>_<timestamp>.txt`, validates Compose syntax (`docker compose config -q`), pulls new images, and runs `docker compose up -d --remove-orphans`.

### 3. Troubleshooting Unhealthy or Restarting Containers
- Inspect exit code, `OOMKilled` status, and healthcheck log output:
  ```bash
  ./scripts/hl-ssh.sh <host> "docker inspect <container> --format '{{json .State}}' | jq ."
  ```
- Inspect real-time container CPU/RAM/Net/Block I/O:
  ```bash
  ./scripts/hl-ssh.sh <host> "docker stats --no-stream"
  ```

### 4. Safe Cleanup
- Only prune dangling images (`docker image prune -f`) by default.
- **Never** run `docker system prune --volumes` without explicit user approval.
