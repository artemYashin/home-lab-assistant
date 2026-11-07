#!/usr/bin/env bash
set -euo pipefail

# Universal Homelab Inventory Manager (Nodes & Services)
# Commands:
#   ./scripts/hl-inventory.sh add-node <name> <ssh_alias> <ip> <role> [notes]
#   ./scripts/hl-inventory.sh remove-node <name>
#   ./scripts/hl-inventory.sh get-node <name> [field: name|ssh_alias|ip|role|notes]
#   ./scripts/hl-inventory.sh add-service <id> <node> <type> <path_or_unit> <url_or_port> [notes] [--with-env]
#   ./scripts/hl-inventory.sh remove-service <id>
#   ./scripts/hl-inventory.sh get-service <id> [field: id|node|type|path|url|notes]
#   ./scripts/hl-inventory.sh list [nodes|services]
#   ./scripts/hl-inventory.sh sync

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS_MD="${REPO_ROOT}/AGENTS.md"
NODES_TSV="${REPO_ROOT}/inventory/nodes.tsv"
SERVICES_TSV="${REPO_ROOT}/inventory/services.tsv"
ENV_EXAMPLE="${REPO_ROOT}/.env.example"

mkdir -p "${REPO_ROOT}/inventory" "${REPO_ROOT}/secrets"

if [[ ! -f "${NODES_TSV}" ]]; then
  printf "name\tssh_alias\tip\trole\tnotes\n" > "${NODES_TSV}"
fi

if [[ ! -f "${SERVICES_TSV}" ]]; then
  printf "id\tnode\ttype\tpath\turl\tnotes\n" > "${SERVICES_TSV}"
fi

sync_agents_md() {
  python3 - "${AGENTS_MD}" "${NODES_TSV}" "${SERVICES_TSV}" <<'PY'
import sys, re, csv

agents_path, nodes_path, services_path = sys.argv[1], sys.argv[2], sys.argv[3]

with open(agents_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Build Nodes Table
node_rows = []
with open(nodes_path, "r", encoding="utf-8") as f:
    reader = csv.DictReader(f, delimiter="\t")
    for row in reader:
        name = (row.get("name") or "").strip()
        if not name:
            continue
        node_rows.append(
            f"| `{name}` | `{row.get('ssh_alias', '-')}` | `{row.get('ip', '-')}` | {row.get('role', '-')} | {row.get('notes', '-')} |"
        )

if not node_rows:
    node_rows.append("| *No nodes registered yet* | `-` | `-` | Run `./scripts/hl-inventory.sh add-node ...` | `-` |")

node_header = (
    "| Node Name | SSH Alias / Host | LAN / VPN IP | Role / OS | Key Paths & Notes |\n"
    "| :--- | :--- | :--- | :--- | :--- |\n"
)
node_block = f"\\1\n{node_header}" + "\n".join(node_rows) + "\n\\2"
content = re.sub(
    r"(<!-- NODE_REGISTRY_START -->).*?(<!-- NODE_REGISTRY_END -->)",
    node_block,
    content,
    flags=re.DOTALL,
)

# 2. Build Services Table
service_rows = []
with open(services_path, "r", encoding="utf-8") as f:
    reader = csv.DictReader(f, delimiter="\t")
    for row in reader:
        sid = (row.get("id") or "").strip()
        if not sid:
            continue
        service_rows.append(
            f"| `{sid}` | `{row.get('node', '-')}` | `{row.get('type', '-')}` | `{row.get('path', '-')}` | `{row.get('url', '-')}` | {row.get('notes', '-')} |"
        )

if not service_rows:
    service_rows.append("| *No services registered yet* | `-` | `-` | Run `./scripts/hl-inventory.sh add-service ...` | `-` | `-` |")

service_header = (
    "| Service ID | Node | Type | Path / Unit / Namespace | URL / Port | Notes |\n"
    "| :--- | :--- | :--- | :--- | :--- | :--- |\n"
)
service_block = f"\\1\n{service_header}" + "\n".join(service_rows) + "\n\\2"
content = re.sub(
    r"(<!-- SERVICE_REGISTRY_START -->).*?(<!-- SERVICE_REGISTRY_END -->)",
    service_block,
    content,
    flags=re.DOTALL,
)

with open(agents_path, "w", encoding="utf-8") as f:
    f.write(content)
PY
}

append_env_template() {
  local service_id="$1"
  local url="${2:-}"
  local prefix
  prefix="$(echo "${service_id}" | tr '[:lower:]-.' '[:upper:]__')"
  if [[ -f "${ENV_EXAMPLE}" ]] && ! grep -q "^${prefix}_URL=" "${ENV_EXAMPLE}"; then
    {
      echo ""
      echo "# Service: ${service_id}"
      echo "${prefix}_URL=${url}"
      echo "${prefix}_API_KEY="
      echo "${prefix}_TOKEN="
    } >> "${ENV_EXAMPLE}"
    echo "Appended ${prefix}_* placeholders to .env.example."
  fi
}

cmd="${1:-list}"
shift || true

case "${cmd}" in
  add-node)
    if [[ $# -lt 4 ]]; then
      echo "Usage: $0 add-node <name> <ssh_alias> <ip> <role> [notes]" >&2
      exit 1
    fi
    name="$1"
    ssh_alias="$2"
    ip="$3"
    role="$4"
    notes="${5:--}"

    awk -F'\t' -v n="${name}" 'NR==1 || $1 != n' "${NODES_TSV}" > "${NODES_TSV}.tmp"
    printf "%s\t%s\t%s\t%s\t%s\n" "${name}" "${ssh_alias}" "${ip}" "${role}" "${notes}" >> "${NODES_TSV}.tmp"
    mv "${NODES_TSV}.tmp" "${NODES_TSV}"
    sync_agents_md
    echo "Saved node '${name}' (${ssh_alias} -> ${ip}) and synced AGENTS.md."
    ;;

  remove-node)
    name="${1:?Usage: $0 remove-node <name>}"
    awk -F'\t' -v n="${name}" 'NR==1 || $1 != n' "${NODES_TSV}" > "${NODES_TSV}.tmp"
    mv "${NODES_TSV}.tmp" "${NODES_TSV}"
    sync_agents_md
    echo "Removed node '${name}' and synced AGENTS.md."
    ;;

  get-node)
    name="${1:?Usage: $0 get-node <name> [field]}"
    field="${2:-all}"
    python3 - "${NODES_TSV}" "${name}" "${field}" <<'PY'
import sys, csv
path, target, field = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, "r", encoding="utf-8") as f:
    for row in csv.DictReader(f, delimiter="\t"):
        if row.get("name") == target:
            if field == "all":
                for k, v in row.items():
                    print(f"{k}={v}")
            elif field in row:
                print(row[field])
            else:
                sys.exit(1)
            sys.exit(0)
sys.exit(1)
PY
    ;;

  add-service)
    with_env=false
    args=()
    for arg in "$@"; do
      if [[ "${arg}" == "--with-env" ]]; then
        with_env=true
      else
        args+=("${arg}")
      fi
    done

    if [[ ${#args[@]} -lt 5 ]]; then
      echo "Usage: $0 add-service <id> <node> <type> <path_or_unit> <url_or_port> [notes] [--with-env]" >&2
      exit 1
    fi
    sid="${args[0]}"
    node="${args[1]}"
    stype="${args[2]}"
    spath="${args[3]}"
    surl="${args[4]}"
    snotes="${args[5]:--}"

    awk -F'\t' -v id="${sid}" 'NR==1 || $1 != id' "${SERVICES_TSV}" > "${SERVICES_TSV}.tmp"
    printf "%s\t%s\t%s\t%s\t%s\t%s\n" "${sid}" "${node}" "${stype}" "${spath}" "${surl}" "${snotes}" >> "${SERVICES_TSV}.tmp"
    mv "${SERVICES_TSV}.tmp" "${SERVICES_TSV}"
    sync_agents_md
    echo "Saved service '${sid}' on '${node}' (${stype}: ${spath}) and synced AGENTS.md."

    if [[ "${with_env}" == "true" ]]; then
      append_env_template "${sid}" "${surl}"
    fi
    ;;

  remove-service)
    sid="${1:?Usage: $0 remove-service <id>}"
    awk -F'\t' -v id="${sid}" 'NR==1 || $1 != id' "${SERVICES_TSV}" > "${SERVICES_TSV}.tmp"
    mv "${SERVICES_TSV}.tmp" "${SERVICES_TSV}"
    sync_agents_md
    echo "Removed service '${sid}' and synced AGENTS.md."
    ;;

  get-service)
    sid="${1:?Usage: $0 get-service <id> [field]}"
    field="${2:-all}"
    python3 - "${SERVICES_TSV}" "${sid}" "${field}" <<'PY'
import sys, csv
path, target, field = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, "r", encoding="utf-8") as f:
    for row in csv.DictReader(f, delimiter="\t"):
        if row.get("id") == target:
            if field == "all":
                for k, v in row.items():
                    print(f"{k}={v}")
            elif field in row:
                print(row[field])
            else:
                sys.exit(1)
            sys.exit(0)
sys.exit(1)
PY
    ;;

  sync)
    sync_agents_md
    echo "Synced AGENTS.md from inventory/nodes.tsv and inventory/services.tsv."
    ;;

  list|list-all)
    target="${1:-all}"
    if [[ "${target}" == "all" || "${target}" == "nodes" ]]; then
      echo "=== NODES (inventory/nodes.tsv) ==="
      column -t -s $'\t' "${NODES_TSV}"
    fi
    if [[ "${target}" == "all" ]]; then
      echo ""
    fi
    if [[ "${target}" == "all" || "${target}" == "services" ]]; then
      echo "=== SERVICES (inventory/services.tsv) ==="
      column -t -s $'\t' "${SERVICES_TSV}"
    fi
    ;;

  *)
    echo "Unknown command: ${cmd}. Use add-node, remove-node, get-node, add-service, remove-service, get-service, list, or sync." >&2
    exit 1
    ;;
esac
