---
name: kubernetes-ops
description: >-
  Use this skill when managing Kubernetes (k3s, k8s, Talos) clusters in the homelab,
  including checking node and pod health, Helm releases, PVCs, Ingresses, and workloads.
---

# Kubernetes (k3s / k8s / Talos) Operations

Use this skill for inspecting, deploying, and debugging Kubernetes workloads in the homelab.

## Helpers & References

- [`k8s-triage.sh`](./scripts/k8s-triage.sh): Full cluster sweep (nodes, non-Running pods, pods with restarts, unbound PVCs, ingresses, recent Warning events). Runs locally or via `--ssh <host>`.
- [`k3s-talos-runbook.md`](./references/k3s-talos-runbook.md): k3s etcd snapshots, `HelmChartConfig` overrides, and `talosctl` commands.

## Workflows

### 1. Fast Cluster Triage
```bash
# If kubeconfig is local:
./.agents/skills/kubernetes-ops/scripts/k8s-triage.sh

# Or run over SSH on the k3s/k8s control plane node:
./.agents/skills/kubernetes-ops/scripts/k8s-triage.sh --ssh <k8s-host>
```

### 2. Workload & Pod Debugging
1. **Describe the Pod** (scheduling constraints, PVC binding, node affinity, events):
   `kubectl describe pod -n <namespace> <pod-name>`
2. **Check current and previous container logs**:
   `kubectl logs -n <namespace> <pod-name> --all-containers --tail=100`
   `kubectl logs -n <namespace> <pod-name> --previous --tail=100`

### 3. Safe Rollouts & Rollbacks
- Watch rollout: `kubectl rollout status deployment/<name> -n <namespace>`
- Undo broken deployment: `kubectl rollout undo deployment/<name> -n <namespace>`
- List Helm releases: `helm list -A`
