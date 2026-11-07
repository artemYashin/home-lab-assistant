#!/usr/bin/env bash
set -euo pipefail

# Nginx Proxy Manager (NPM) REST API Helper
# Manages NPM Proxy Hosts & Certificates cleanly via its API (never edit /data/nginx/proxy_host/*.conf directly).
#
# Credentials (from .env or secrets/npm.env):
#   NPM_URL=http://<host>:81
#   NPM_USER=admin@example.com
#   NPM_PASSWORD=...
#
# Usage:
#   ./npm-api.sh list-hosts
#   ./npm-api.sh list-certs
#   ./npm-api.sh add-host <domain> <forward_host> <forward_port> [scheme: http|https] [cert_id: 0]
#   ./npm-api.sh delete-host <id>

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
[[ -f "${REPO_ROOT}/.env" ]] && set -a && source "${REPO_ROOT}/.env" && set +a
[[ -f "${REPO_ROOT}/secrets/npm.env" ]] && set -a && source "${REPO_ROOT}/secrets/npm.env" && set +a

NPM_URL="${NPM_URL:-}"
NPM_USER="${NPM_USER:-}"
NPM_PASSWORD="${NPM_PASSWORD:-}"

if [[ -z "${NPM_URL}" || -z "${NPM_USER}" || -z "${NPM_PASSWORD}" ]]; then
  echo "Error: NPM_URL, NPM_USER, and NPM_PASSWORD must be set in .env or secrets/npm.env" >&2
  echo "Example: NPM_URL=http://192.168.1.10:81" >&2
  exit 1
fi

NPM_URL="${NPM_URL%/}"

get_jwt() {
  local resp
  resp="$(curl -sS -X POST "${NPM_URL}/api/tokens" \
    -H "Content-Type: application/json" \
    -d "$(python3 -c 'import json,sys; print(json.dumps({"identity":sys.argv[1],"secret":sys.argv[2]}))' "${NPM_USER}" "${NPM_PASSWORD}")")"
  python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); print(d["token"])' <<<"${resp}"
}

cmd="${1:-list-hosts}"
shift || true

TOKEN="$(get_jwt)"

case "${cmd}" in
  list-hosts)
    curl -sS "${NPM_URL}/api/nginx/proxy-hosts" \
      -H "Authorization: Bearer ${TOKEN}" | python3 -c '
import json, sys
hosts = json.loads(sys.stdin.read())
print(f"{\"ID\":<5} {\"ENABLED\":<8} {\"DOMAINS\":<35} {\"FORWARD TARGET\":<28} {\"SSL_ID\"}")
print("-" * 88)
for h in hosts:
    domains = ",".join(h.get("domain_names", []))
    target = f"{h.get(\"forward_scheme\")}://{h.get(\"forward_host\")}:{h.get(\"forward_port\")}"
    print(f"{h.get(\"id\"):<5} {str(bool(h.get(\"enabled\"))):<8} {domains:<35} {target:<28} {h.get(\"certificate_id\")}")
'
    ;;

  list-certs)
    curl -sS "${NPM_URL}/api/nginx/certificates" \
      -H "Authorization: Bearer ${TOKEN}" | python3 -c '
import json, sys
certs = json.loads(sys.stdin.read())
print(f"{\"ID\":<5} {\"NICE NAME\":<30} {\"DOMAINS\":<40} {\"EXPIRES\"}")
print("-" * 95)
for c in certs:
    domains = ",".join(c.get("domain_names", []))
    print(f"{c.get(\"id\"):<5} {(c.get(\"nice_name\") or \"-\"):<30} {domains:<40} {c.get(\"expires_on\")}")
'
    ;;

  add-host)
    if [[ $# -lt 3 ]]; then
      echo "Usage: $0 add-host <domain> <forward_host> <forward_port> [scheme: http|https] [cert_id: 0]" >&2
      exit 1
    fi
    domain="$1"
    fhost="$2"
    fport="$3"
    fscheme="${4:-http}"
    cert_id="${5:-0}"

    payload="$(python3 - "${domain}" "${fhost}" "${fport}" "${fscheme}" "${cert_id}" <<'PY'
import json, sys
domain, fhost, fport, fscheme, cert_id = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4], int(sys.argv[5])
body = {
    "domain_names": [domain],
    "forward_scheme": fscheme,
    "forward_host": fhost,
    "forward_port": fport,
    "access_list_id": 0,
    "certificate_id": cert_id,
    "ssl_forced": bool(cert_id > 0),
    "caching_enabled": False,
    "block_exploits": True,
    "allow_websocket_upgrade": True,
    "http2_support": bool(cert_id > 0),
    "hsts_enabled": False,
    "hsts_subdomains": False,
    "advanced_config": "",
    "meta": {"letsencrypt_agree": False, "dns_challenge": False},
    "locations": [],
}
print(json.dumps(body))
PY
)"
    resp="$(curl -sS -X POST "${NPM_URL}/api/nginx/proxy-hosts" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json" \
      -d "${payload}")"
    python3 -c '
import json, sys
d = json.loads(sys.stdin.read())
if "id" in d:
    print(f"Created NPM Proxy Host ID {d[\"id\"]}: {d[\"domain_names\"]} -> {d[\"forward_scheme\"]}://{d[\"forward_host\"]}:{d[\"forward_port\"]}")
else:
    print("Error creating proxy host:", json.dumps(d, indent=2), file=sys.stderr)
    sys.exit(1)
' <<<"${resp}"
    ;;

  delete-host)
    host_id="${1:?Usage: $0 delete-host <id>}"
    curl -sS -X DELETE "${NPM_URL}/api/nginx/proxy-hosts/${host_id}" \
      -H "Authorization: Bearer ${TOKEN}" >/dev/null
    echo "Deleted NPM Proxy Host ID ${host_id}."
    ;;

  *)
    echo "Usage: $0 {list-hosts|list-certs|add-host|delete-host} ..." >&2
    exit 1
    ;;
esac
