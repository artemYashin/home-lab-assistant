#!/usr/bin/env bash
set -euo pipefail

# Helper script for fast, non-interactive SSH commands to homelab hosts.
# Usage:
#   ./scripts/hl-ssh.sh <ssh-host> "<command>"
#   ./scripts/hl-ssh.sh --check <ssh-host>

CONTROL_DIR="${HOME}/.ssh/ctl"
mkdir -p -m 700 "${CONTROL_DIR}"

SSH_OPTS=(
  -o BatchMode=yes
  -o ConnectTimeout=8
  -o ControlMaster=auto
  -o "ControlPath=${CONTROL_DIR}/%r@%h:%p"
  -o ControlPersist=10m
)

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 [--check] <ssh-host> [command...]" >&2
  exit 1
fi

if [[ "$1" == "--check" ]]; then
  HOST="${2:?Missing ssh-host}"
  echo "Checking SSH connectivity to ${HOST}..."
  ssh "${SSH_OPTS[@]}" "${HOST}" "echo 'Connected to:' \$(hostname -f 2>/dev/null || hostname) '|' \$(uname -sr) '| Uptime:' \$(uptime -p 2>/dev/null || uptime)"
  exit 0
fi

HOST="$1"
shift

if [[ $# -eq 0 ]]; then
  echo "Error: Provide a command to execute on ${HOST}" >&2
  exit 1
fi

ssh "${SSH_OPTS[@]}" "${HOST}" "$@"
