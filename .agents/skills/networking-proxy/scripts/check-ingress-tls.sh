#!/usr/bin/env bash
set -euo pipefail

# Check DNS resolution, HTTP status, and TLS certificate expiration for homelab domains.
# Usage:
#   ./check-ingress-tls.sh <domain1> [domain2 ...]
#   DNS_SERVER=192.168.1.2 ./check-ingress-tls.sh jellyfin.lab.local sonarr.lab.local

if [[ $# -lt 1 ]]; then
  echo "Usage: [DNS_SERVER=<ip>] $0 <domain1> [domain2 ...]" >&2
  exit 1
fi

DNS_SERVER="${DNS_SERVER:-}"

printf "%-32s | %-15s | %-9s | %-25s\n" "DOMAIN" "RESOLVED IP" "HTTP CODE" "TLS EXPIRY"
printf -- "---------------------------------+-----------------+-----------+--------------------------\n"

for domain in "$@"; do
  if [[ -n "${DNS_SERVER}" ]] && command -v dig >/dev/null 2>&1; then
    ip="$(dig +short "@${DNS_SERVER}" "${domain}" A | tail -n1)"
  elif command -v dig >/dev/null 2>&1; then
    ip="$(dig +short "${domain}" A | tail -n1)"
  else
    ip="$(getent ahostsv4 "${domain}" 2>/dev/null | awk 'NR==1{print $1}' || true)"
  fi
  ip="${ip:-UNRESOLVED}"

  http_code="$(curl -ksS -o /dev/null -w '%{http_code}' --max-time 5 "https://${domain}" 2>/dev/null || echo "ERR")"

  if [[ "${ip}" != "UNRESOLVED" ]]; then
    expiry="$(echo | timeout 5 openssl s_client -servername "${domain}" -connect "${ip}:443" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2 || echo "No TLS")"
  else
    expiry="N/A"
  fi

  printf "%-32s | %-15s | %-9s | %-25s\n" "${domain}" "${ip}" "${http_code}" "${expiry}"
done
