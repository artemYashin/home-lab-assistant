#!/usr/bin/env bash
set -euo pipefail

# Run a comprehensive host incident & log triage sweep over SSH.
# Usage: ./host-triage.sh <host>

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
HL_SSH="${REPO_ROOT}/scripts/hl-ssh.sh"
HOST="${1:?Usage: $0 <host>}"

"${HL_SSH}" "${HOST}" '
  echo "=== UPTIME & LOAD ==="
  uptime
  echo ""
  echo "=== PRESSURE STALL INFORMATION (PSI) ==="
  for res in cpu memory io; do
    [ -f "/proc/pressure/$res" ] && echo "[$res]" && cat "/proc/pressure/$res"
  done
  echo ""
  echo "=== MEMORY & SWAP ==="
  free -h
  echo ""
  echo "=== TOP 10 CPU PROCESSES ==="
  ps aux --sort=-%cpu | head -n 11
  echo ""
  echo "=== TOP 10 MEMORY PROCESSES ==="
  ps aux --sort=-%mem | head -n 11
  echo ""
  echo "=== FAILED SYSTEMD UNITS ==="
  systemctl --failed --no-pager
  echo ""
  echo "=== RECENT KERNEL / OOM / I/O ERRORS ==="
  dmesg -T --level=emerg,alert,crit,err 2>/dev/null | tail -n 25 || journalctl -k -p err -n 25 --no-pager
  if command -v docker >/dev/null 2>&1; then
    echo ""
    echo "=== UNHEALTHY OR EXITED CONTAINERS ==="
    docker ps -a --filter "health=unhealthy" --filter "status=exited" --filter "status=restarting" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
  fi
'
