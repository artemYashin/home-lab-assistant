#!/usr/bin/env bash
set -euo pipefail

# Manage remote Docker Compose stacks with pre-update digest snapshots.
# Usage:
#   ./remote-compose.sh <host> list
#   ./remote-compose.sh <host> status <stack_dir>
#   ./remote-compose.sh <host> logs <stack_dir> [service]
#   ./remote-compose.sh <host> validate <stack_dir>
#   ./remote-compose.sh <host> update <stack_dir>

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
HL_SSH="${REPO_ROOT}/scripts/hl-ssh.sh"
SNAPSHOT_DIR="${REPO_ROOT}/stacks/snapshots"
mkdir -p "${SNAPSHOT_DIR}"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <host> <list|status|logs|validate|update> [stack_dir] [service]" >&2
  exit 1
fi

HOST="$1"
ACTION="$2"
STACK_DIR="${3:-}"
SERVICE="${4:-}"

case "${ACTION}" in
  list)
    "${HL_SSH}" "${HOST}" "docker compose ls && echo '---' && docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.RunningFor}}'"
    ;;
  status)
    [[ -n "${STACK_DIR}" ]] || { echo "Missing stack_dir" >&2; exit 1; }
    "${HL_SSH}" "${HOST}" "cd '${STACK_DIR}' && docker compose ps && echo '---' && docker compose images"
    ;;
  logs)
    [[ -n "${STACK_DIR}" ]] || { echo "Missing stack_dir" >&2; exit 1; }
    "${HL_SSH}" "${HOST}" "cd '${STACK_DIR}' && docker compose logs --tail=100 ${SERVICE}"
    ;;
  validate)
    [[ -n "${STACK_DIR}" ]] || { echo "Missing stack_dir" >&2; exit 1; }
    "${HL_SSH}" "${HOST}" "cd '${STACK_DIR}' && docker compose config -q && echo 'Compose syntax OK'"
    ;;
  update)
    [[ -n "${STACK_DIR}" ]] || { echo "Missing stack_dir" >&2; exit 1; }
    STACK_SLUG="$(basename "${STACK_DIR}")"
    STAMP="$(date +%Y%m%d-%H%M%S)"
    SNAP_FILE="${SNAPSHOT_DIR}/${HOST}_${STACK_SLUG}_${STAMP}.txt"
    echo "Saving pre-update image digests to ${SNAP_FILE}..."
    "${HL_SSH}" "${HOST}" "cd '${STACK_DIR}' && docker compose images" | tee "${SNAP_FILE}"
    echo "Validating, pulling, and recreating changed containers..."
    "${HL_SSH}" "${HOST}" "cd '${STACK_DIR}' && docker compose config -q && docker compose pull && docker compose up -d --remove-orphans && docker compose ps"
    ;;
  *)
    echo "Unknown action: ${ACTION}" >&2
    exit 1
    ;;
esac
