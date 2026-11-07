#!/usr/bin/env bash
set -euo pipefail

# Comprehensive Kubernetes cluster triage (runs locally or over SSH if --ssh <host> is passed)
# Usage:
#   ./k8s-triage.sh [--ssh <host>]

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
HL_SSH="${REPO_ROOT}/scripts/hl-ssh.sh"

run_k8s() {
  local script='
    echo "=== NODES ==="
    kubectl get nodes -o wide
    echo ""
    echo "=== NON-RUNNING / UNHEALTHY PODS ==="
    kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
    echo ""
    echo "=== PODS WITH RESTARTS (>0) ==="
    kubectl get pods -A -o jsonpath="{range .items[*]}{.metadata.namespace}{\"\t\"}{.metadata.name}{\"\t\"}{range .status.containerStatuses[*]}{.restartCount}{\" \"}{end}{\"\n\"}{end}" | awk "\$3 > 0" | column -t || true
    echo ""
    echo "=== UNBOUND PVCs ==="
    kubectl get pvc -A | grep -vE "Bound|STATUS" || echo "All PVCs Bound"
    echo ""
    echo "=== INGRESSES ==="
    kubectl get ingress -A
    echo ""
    echo "=== RECENT WARNING EVENTS ==="
    kubectl get events -A --field-selector type=Warning --sort-by=".lastTimestamp" | tail -n 25
  '
  if [[ "${1:-}" == "--ssh" ]]; then
    local host="${2:?Missing SSH host}"
    "${HL_SSH}" "${host}" "${script}"
  else
    bash -c "${script}"
  fi
}

run_k8s "$@"
