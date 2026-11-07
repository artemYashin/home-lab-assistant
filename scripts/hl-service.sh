#!/usr/bin/env bash
set -euo pipefail

# Universal Homelab Service Controller
# Operates ANY service registered in inventory/services.tsv, regardless of runtime.
#
# Usage:
#   ./scripts/hl-service.sh status [service_id|--all]
#   ./scripts/hl-service.sh logs <service_id> [lines]
#   ./scripts/hl-service.sh restart <service_id>
#   ./scripts/hl-service.sh update <service_id>
#   ./scripts/hl-service.sh env <service_id>
#   ./scripts/hl-service.sh discover <node> [--apply]

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INVENTORY="${REPO_ROOT}/scripts/hl-inventory.sh"
SSH="${REPO_ROOT}/scripts/hl-ssh.sh"
REMOTE_COMPOSE="${REPO_ROOT}/.agents/skills/docker-stacks/scripts/remote-compose.sh"
SERVICES_TSV="${REPO_ROOT}/inventory/services.tsv"

load_service_meta() {
  local sid="$1"
  if ! eval "$(python3 - "${SERVICES_TSV}" "${sid}" <<'PY'
import sys, csv, shlex
path, target = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as f:
    for row in csv.DictReader(f, delimiter="\t"):
        if row.get("id") == target:
            for k in ("id", "node", "type", "path", "url", "notes"):
                val = (row.get(k) or "").strip()
                print(f"SVC_{k.upper()}={shlex.quote(val)}")
            sys.exit(0)
sys.exit(1)
PY
)"; then
    echo "Error: Service '${sid}' not found in inventory/services.tsv." >&2
    echo "Register it with: ./scripts/hl-inventory.sh add-service <id> <node> <type> <path> <url> [notes]" >&2
    exit 1
  fi

  # Resolve node name -> ssh_alias if registered in nodes.tsv, otherwise use SVC_NODE directly
  SVC_HOST="$("${INVENTORY}" get-node "${SVC_NODE}" ssh_alias 2>/dev/null || echo "${SVC_NODE}")"
}

load_service_env() {
  local sid="$1"
  local prefix
  prefix="$(echo "${sid}" | tr '[:lower:]-.' '[:upper:]__')"
  [[ -f "${REPO_ROOT}/.env" ]] && set -a && source "${REPO_ROOT}/.env" && set +a
  [[ -f "${REPO_ROOT}/secrets/${sid}.env" ]] && set -a && source "${REPO_ROOT}/secrets/${sid}.env" && set +a

  echo "# Resolved environment for service '${sid}' (prefix: ${prefix}_*)"
  env | grep -E "^${prefix}_" || echo "# (no ${prefix}_* variables set in .env or secrets/${sid}.env)"
}

check_single_status() {
  local sid="$1"
  load_service_meta "${sid}"
  echo "=== [${SVC_ID}] node=${SVC_NODE} (${SVC_HOST}) | type=${SVC_TYPE} | path=${SVC_PATH} ==="

  case "${SVC_TYPE}" in
    compose|docker-compose)
      "${SSH}" "${SVC_HOST}" "cd '${SVC_PATH}' && docker compose ps"
      ;;
    docker|container)
      "${SSH}" "${SVC_HOST}" "docker ps --filter 'name=${SVC_PATH}' --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}'"
      ;;
    systemd|service)
      "${SSH}" "${SVC_HOST}" "systemctl status '${SVC_PATH}' --no-pager -l | head -n 20"
      ;;
    k8s|kubernetes)
      # SVC_PATH format: namespace/resource or namespace
      local ns="${SVC_PATH%%/*}"
      local res="${SVC_PATH#*/}"
      if [[ "${ns}" == "${res}" ]]; then
        "${SSH}" "${SVC_HOST}" "kubectl get pods,svc,ingress -n '${ns}'"
      else
        "${SSH}" "${SVC_HOST}" "kubectl get '${res}' -n '${ns}' -o wide"
      fi
      ;;
    external|http|*)
      echo "Runtime check skipped for type '${SVC_TYPE}'."
      ;;
  esac

  if [[ -n "${SVC_URL}" && "${SVC_URL}" != "-" && "${SVC_URL}" =~ ^https?:// ]]; then
    local code
    code="$(curl -ks -o /dev/null -w '%{http_code}' --max-time 5 "${SVC_URL}" || echo "ERR")"
    echo "HTTP Reachability (${SVC_URL}): ${code}"
  fi
}

cmd="${1:-status}"
shift || true

case "${cmd}" in
  status)
    target="${1:---all}"
    if [[ "${target}" == "--all" ]]; then
      mapfile -t sids < <(awk -F'\t' 'NR>1 && $1 != "" {print $1}' "${SERVICES_TSV}")
      if [[ ${#sids[@]} -eq 0 ]]; then
        echo "No services registered in inventory/services.tsv yet."
        exit 0
      fi
      for s in "${sids[@]}"; do
        check_single_status "${s}"
        echo ""
      done
    else
      check_single_status "${target}"
    fi
    ;;

  logs)
    sid="${1:?Usage: $0 logs <service_id> [lines]}"
    lines="${2:-100}"
    load_service_meta "${sid}"
    case "${SVC_TYPE}" in
      compose|docker-compose)
        "${SSH}" "${SVC_HOST}" "cd '${SVC_PATH}' && docker compose logs --tail='${lines}' --no-color"
        ;;
      docker|container)
        "${SSH}" "${SVC_HOST}" "docker logs --tail='${lines}' '${SVC_PATH}'"
        ;;
      systemd|service)
        "${SSH}" "${SVC_HOST}" "journalctl -u '${SVC_PATH}' -n '${lines}' --no-pager"
        ;;
      k8s|kubernetes)
        ns="${SVC_PATH%%/*}"
        res="${SVC_PATH#*/}"
        "${SSH}" "${SVC_HOST}" "kubectl logs -n '${ns}' '${res}' --tail='${lines}'"
        ;;
      *)
        echo "Logs not supported for service type '${SVC_TYPE}'." >&2
        exit 1
        ;;
    esac
    ;;

  restart)
    sid="${1:?Usage: $0 restart <service_id>}"
    load_service_meta "${sid}"
    case "${SVC_TYPE}" in
      compose|docker-compose)
        "${SSH}" "${SVC_HOST}" "cd '${SVC_PATH}' && docker compose restart"
        ;;
      docker|container)
        "${SSH}" "${SVC_HOST}" "docker restart '${SVC_PATH}'"
        ;;
      systemd|service)
        "${SSH}" "${SVC_HOST}" "sudo systemctl restart '${SVC_PATH}'"
        ;;
      k8s|kubernetes)
        ns="${SVC_PATH%%/*}"
        res="${SVC_PATH#*/}"
        "${SSH}" "${SVC_HOST}" "kubectl rollout restart -n '${ns}' '${res}'"
        ;;
      *)
        echo "Restart not supported for service type '${SVC_TYPE}'." >&2
        exit 1
        ;;
    esac
    ;;

  update)
    sid="${1:?Usage: $0 update <service_id>}"
    load_service_meta "${sid}"
    case "${SVC_TYPE}" in
      compose|docker-compose)
        "${REMOTE_COMPOSE}" "${SVC_HOST}" update "${SVC_PATH}"
        ;;
      docker|container)
        echo "Standalone container '${SVC_PATH}': prefer migrating to a Compose file or recreating manually." >&2
        exit 1
        ;;
      *)
        echo "Automated update is currently implemented for 'compose' services (got '${SVC_TYPE}')." >&2
        exit 1
        ;;
    esac
    ;;

  env)
    sid="${1:?Usage: $0 env <service_id>}"
    load_service_env "${sid}"
    ;;

  discover)
    node="${1:?Usage: $0 discover <node> [--apply]}"
    apply_flag="${2:-}"
    host="$("${INVENTORY}" get-node "${node}" ssh_alias 2>/dev/null || echo "${node}")"

    echo "Scanning node '${node}' (${host}) for Docker Compose stacks & containers..."
    raw_compose="$("${SSH}" "${host}" "docker compose ls --format json 2>/dev/null || echo '[]'")"

    python3 - "${node}" "${raw_compose}" "${apply_flag}" "${INVENTORY}" <<'PY'
import sys, json, os, subprocess

node, raw_json, apply_flag, inv_script = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
try:
    projects = json.loads(raw_json)
except Exception:
    projects = []

if not projects:
    print("No running Docker Compose stacks reported by `docker compose ls`.")
    sys.exit(0)

for p in projects:
    name = p.get("Name") or ""
    cfg = (p.get("ConfigFiles") or "").split(",")[0].strip()
    workdir = os.path.dirname(cfg) if cfg else "-"
    status = p.get("Status") or "running"
    if not name:
        continue
    if apply_flag == "--apply":
        subprocess.run([inv_script, "add-service", name, node, "compose", workdir, "-", f"Auto-discovered ({status})"], check=True)
    else:
        print(f"./scripts/hl-inventory.sh add-service {name!r} {node!r} 'compose' {workdir!r} '-' 'Auto-discovered ({status})'")
PY
    ;;

  *)
    echo "Usage: $0 {status|logs|restart|update|env|discover} ..." >&2
    exit 1
    ;;
esac
