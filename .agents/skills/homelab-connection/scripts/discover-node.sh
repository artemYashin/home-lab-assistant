#!/usr/bin/env bash
set -euo pipefail

# Run a read-only discovery sweep on a remote homelab node via SSH.
# Usage: ./discover-node.sh <ssh_alias_or_host>

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
HL_SSH="${REPO_ROOT}/scripts/hl-ssh.sh"

HOST="${1:?Usage: $0 <ssh_alias_or_host>}"

"${HL_SSH}" "${HOST}" '
  echo "=== HOST & OS ==="
  hostnamectl 2>/dev/null || uname -a
  echo "=== CPU & MEMORY ==="
  lscpu 2>/dev/null | grep -E "Architecture|Model name|Socket|CPU\(s\):" || true
  free -h
  echo "=== NETWORK INTERFACES ==="
  ip -br addr show
  echo "=== STORAGE & FILESYSTEMS ==="
  df -hT -x tmpfs -x devtmpfs -x overlay -x squashfs
  if command -v zpool >/dev/null 2>&1; then
    echo "=== ZFS POOLS ==="
    zpool list
    zpool status -x
  fi
  if command -v docker >/dev/null 2>&1; then
    echo "=== DOCKER COMPOSE STACKS ==="
    docker compose ls 2>/dev/null || true
    echo "=== DOCKER CONTAINERS ==="
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || true
  fi
  if command -v kubectl >/dev/null 2>&1; then
    echo "=== KUBERNETES NODES ==="
    kubectl get nodes -o wide 2>/dev/null || true
  fi
  echo "=== LISTENING TCP PORTS ==="
  ss -tlnp 2>/dev/null | head -n 40
'
