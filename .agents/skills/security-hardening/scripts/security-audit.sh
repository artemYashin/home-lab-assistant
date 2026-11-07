#!/usr/bin/env bash
set -euo pipefail

# Read-only security audit on a homelab host over SSH.
# Usage: ./security-audit.sh <host>

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
HL_SSH="${REPO_ROOT}/scripts/hl-ssh.sh"
HOST="${1:?Usage: $0 <host>}"

"${HL_SSH}" "${HOST}" '
  echo "=== SSHD EFFECTIVE SETTINGS ==="
  sudo -n sshd -T 2>/dev/null | grep -E "^(port|permitrootlogin|passwordauthentication|pubkeyauthentication|kbdinteractiveauthentication) " || grep -E "^[^#]*(Port|PermitRootLogin|PasswordAuthentication|PubkeyAuthentication)" /etc/ssh/sshd_config 2>/dev/null || true
  echo ""
  echo "=== NON-LOOPBACK LISTENING PORTS ==="
  ss -tulpn | awk "NR==1 || (\$5 !~ /^127\\./ && \$5 !~ /^\\[::1\\]/)"
  echo ""
  echo "=== DOCKER PORTS BOUND TO 0.0.0.0 (BYPASSES UFW) ==="
  if command -v docker >/dev/null 2>&1; then
    docker ps --format "table {{.Names}}\t{{.Ports}}" | grep "0.0.0.0:" || echo "None bound to 0.0.0.0"
  fi
  echo ""
  echo "=== RECENT FAILED SSH LOGINS ==="
  journalctl -u ssh -u sshd -n 50 --no-pager 2>/dev/null | grep -iE "failed|invalid" | tail -n 10 || echo "No recent failed SSH logins"
'
