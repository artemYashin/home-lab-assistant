#!/usr/bin/env bash
set -euo pipefail

# Safely configure a Host block in ~/.ssh/config for a homelab node.
# Usage: ./setup-ssh-host.sh <alias> <hostname_or_ip> [user] [port] [identity_file]

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <alias> <hostname_or_ip> [user] [port] [identity_file]" >&2
  exit 1
fi

ALIAS="$1"
HOSTNAME="$2"
USER_NAME="${3:-${USER}}"
PORT="${4:-22}"
IDENTITY_FILE="${5:-~/.ssh/id_ed25519}"

SSH_DIR="${HOME}/.ssh"
SSH_CONFIG="${SSH_DIR}/config"
mkdir -p -m 700 "${SSH_DIR}"
touch "${SSH_CONFIG}"
chmod 600 "${SSH_CONFIG}"

if grep -qE "^Host[[:space:]]+${ALIAS}([[:space:]]|$)" "${SSH_CONFIG}"; then
  echo "Host alias '${ALIAS}' already exists in ${SSH_CONFIG}."
else
  cat >> "${SSH_CONFIG}" <<EOF

Host ${ALIAS}
    HostName ${HOSTNAME}
    User ${USER_NAME}
    Port ${PORT}
    IdentityFile ${IDENTITY_FILE}
    ServerAliveInterval 30
    ServerAliveCountMax 3
EOF
  echo "Added Host '${ALIAS}' (${USER_NAME}@${HOSTNAME}:${PORT}) to ${SSH_CONFIG}."
fi
